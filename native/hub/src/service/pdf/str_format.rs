use ahash::HashMap;
use nom::branch::alt;
use nom::Parser;
/// 字符串格式化表达式模块
/// 期望支持以下表达式
/// `xxxx-{tagA}-{tagB}-{{-}}-{tagA[2:]}-{tagB[:9]}-{tagA[2:8]}-xxx`
use nom::bytes::complete::{tag, take_till, take_until};
use nom::character::complete::{char, digit0, u32};
use nom::error::ErrorKind;
use nom::IResult;
use nom::sequence::{delimited, separated_pair};

pub type FormatString<'a> = Vec<ParserEnum<'a>>;

#[derive(Debug)]
enum ParserEnum<'a> {
    GeneralString(&'a str),
    Tag(TagData<'a>)
}

#[derive(Debug)]
struct TagData<'a> {
    tag: &'a str,
    start: Option<u32>,
    end: Option<u32>
}

impl TagData<'_> {
    fn format(&self, data: &str) -> anyhow::Result<&str> {
        let mut data = data.chars();
        if let Some(start) = self.start {
            data = data.skip(start as usize);
        }
        if let Some(end) = self.end {
            data = data.take(end as usize);
        }

        Ok(())
    }
}

impl ParserEnum<'_> {
    fn write_to_string(&self, buf: &mut String) {
        match self {
            ParserEnum::GeneralString(s) => {
                buf.push_str(s);
            }
            ParserEnum::Tag(d) => {
                buf.push_str(d.tag);
            }
        }
    }
}


/// 获取字符串中标签外的数据 直到`{`或`}`
fn find_tag(input: &str) -> IResult<&str, ParserEnum<'_>> {
    let (input, output) = take_till(|c| c == '{' || c == '}').parse(input)?;

    Ok((input, ParserEnum::GeneralString(output)))
}

/// 处理`{{`数据
fn handle_double_brace_start(input: &str) -> IResult<&str, ParserEnum<'_>> {
    let (input, _) = tag("{{")(input)?;
    Ok((input, ParserEnum::GeneralString("{")))
}

/// 处理`}}`数据
fn handle_double_brace_end(input: &str) -> IResult<&str, ParserEnum<'_>> {
    let (input, _) = tag("}}")(input)?;
    Ok((input, ParserEnum::GeneralString("}")))
}

/// 提取`{}`之间的数据
fn handle_brace_data(input: & str) -> IResult<& str, ParserEnum<'_>> {
    let (input, output) = delimited(char('{'), take_until("}"), char('}')).parse(input)?;
    Ok((input, handle_tag_data(output.trim())?.1))
}

/// 处理标签中的数据
fn handle_tag_data(input: &str) -> IResult<&str, ParserEnum<'_>> {
    // 1. 获取标签名称
    let (input, tag) = take_until("[")(input)?;
    let tag = tag.trim();
    if input.is_empty() {
        return Ok((input, ParserEnum::Tag(TagData {
            tag,
            start: None,
            end: None
        })));
    }

    // 2. 获取标签内的参数 output == '1:9' || ':9' || '1:' ':'
    let (_input, output) = delimited(char('['), take_until("]"), char(']')).parse(input.trim())?;
    let output = output.trim();
    let (input, (start, end)) = separated_pair(digit0, char(':'), digit0).parse(output)?;
    let start = if !start.trim().is_empty() {
        Some(u32(start.trim())?.1)
    } else {
        None
    };
    let end = if !end.trim().is_empty() {
        Some(u32(end.trim())?.1)
    } else {
        None
    };

    Ok((input, ParserEnum::Tag(TagData {
        tag,
        start,
        end,
    })))
}

/// 判断是否为空数据
fn empty_data(input: &str) -> IResult<&str, ParserEnum<'_>> {
    if input.is_empty() {
        Ok((input, ParserEnum::GeneralString("")))
    } else {
        Err(nom::Err::Error(nom::error::Error {
            input,
            code: ErrorKind::Eof,
        }))
    }
}

fn once(input: &str)  -> IResult<&str, (ParserEnum<'_>, ParserEnum<'_>)>{
    // 1. 查找数据直到标签
    let (input, output1) = find_tag.parse(input)?;

    // 2. 处理标签
    let (input,  output2) = alt((handle_double_brace_end, handle_double_brace_start, handle_brace_data, empty_data)).parse(input)?;

    Ok((input, (output1, output2)))
}

/// 模板解析
pub fn parser_template(template: &str) -> anyhow::Result<FormatString> {
    let mut outputs = Vec::new();
    let mut input = template;

    loop {
        if input.is_empty() {
            break;
        }
        match once(input) {
            Ok((i1, (o1, o2))) => {
                input = i1;
                outputs.push(o1);
                outputs.push(o2);
            },
            Err(e) => {
                return Err(anyhow::anyhow!(e.to_owned()));
            }
        }
    }

    Ok(outputs)
}

/// 生成数据
fn format_string(format_string: &FormatString, data: &HashMap<&str, &str>) -> anyhow::Result<String> {
    let mut result = String::new();
    for output in format_string {
        match output {
            ParserEnum::GeneralString(s) => {
                result.push_str(s);
            },
            ParserEnum::Tag(tag) => {
              let value = data.get(tag.tag).ok_or_else(|| anyhow::anyhow!("tag {0} not found", tag.tag))?;
                result.push_str(value);
            },
        };
    }

    Ok(result)
}



mod test {
    use nom::{ErrorConvert, Finish};
    use nom::character::complete::alpha0;
    use nom::error::{context, dbg_dmp};
    use nom::multi::many0;
    use super::*;

    #[test]
    fn test_find_tag() {
        let input = "123{abc";
        let (input, output) = find_tag(input).unwrap();
        match output {
            ParserEnum::GeneralString(s) => {
                assert_eq!(input, "{abc");
                assert_eq!(s, "123");
            }
            ParserEnum::Tag(_) => {
                panic!("expect GeneralString");
            }
        }

        let input = "123}{abc";
        let (input, output) = find_tag(input).unwrap();
        match output {
            ParserEnum::GeneralString(s) => {
                assert_eq!(input, "}{abc");
                assert_eq!(s, "123");
            }
            ParserEnum::Tag(_) => {
                panic!("expect GeneralString");
            }
        }
    }

    #[test]
    fn test_handle_brace_data() {
        let input = "{tagA[2:9]}";
        let (input, output) = handle_brace_data(input).unwrap();
        match output {
            ParserEnum::GeneralString(_) => {}
            ParserEnum::Tag(d) => {
                assert_eq!(d.tag, "tagA");
                println!("output: {:?}", d);
            }
        };
        println!("input: {}", input);
    }

    #[test]
    fn test_once() {
        let input = "123{tagA[2:9]}abc";
        let (input, (output1, output2)) = once(input).unwrap();
        assert_eq!("abc", input);
        match output1 {
            ParserEnum::GeneralString(d) => {
                assert_eq!("123", d);
            }
            ParserEnum::Tag(_) => {
                panic!("expect GeneralString");
            }
        };

        match output2 {
            ParserEnum::GeneralString(_) => {
                panic!("expect Tag");
            }
            ParserEnum::Tag(d) => {
                assert_eq!("tagA", d.tag);
                println!("output: {:?}", d);
            }
        };

        let input = "123{{abc";
        let (input, (output1, output2)) = once(input).unwrap();
        assert_eq!("abc", input);
        match output1 {
            ParserEnum::GeneralString(d) => {
                assert_eq!("123", d);
            }
            ParserEnum::Tag(_) => {
                panic!("expect GeneralString");
            }
        };

        match output2 {
            ParserEnum::GeneralString(d) => {
                assert_eq!("{", d);
            }
            ParserEnum::Tag(_) => {
               panic!("expect GeneralString");
            }
        };

        let input = "123";
        let (input, (output1, output2)) = once(input).unwrap();
        assert_eq!("", input);
        println!("output2: {:?}", output2);
    }

    #[test]
    fn test_parse() {
        let input = "123{tagA[2:9]}abc{{-}}";
        // let result = parse(input).unwrap();
        // assert_eq!(result, "123tagAabc{-}");
    }
}