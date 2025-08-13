use std::fs;
use std::path::PathBuf;

const WINDOWS_LIB_PDF: &str = "pdfium.dll";
const LINUX_LIB_PDF: &str = "libpdfium.so";

fn main() {
    // 获取编译输出目录（target/debug或target/release）
    let out_dir = PathBuf::from(std::env::var("OUT_DIR").unwrap());
    println!("out_dir: {:?}", out_dir);
    // 项目根路径
    let project_root = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());
    println!("project_root: {:?}", project_root);

    // 定义源目录（assets下的so文件）
    let mut assets = PathBuf::from("assets");
    assets.push("pdfium");
    let mut output = out_dir.clone();
    if cfg!(target_os = "windows") {
        assets.push(WINDOWS_LIB_PDF);
        output.push(WINDOWS_LIB_PDF);
    } else if cfg!(target_os = "linux") {
        assets.push(LINUX_LIB_PDF);
        output.push(LINUX_LIB_PDF);
    }

    // 复制文件到目标目录
    fs::copy(&assets, &output).expect(&format!("复制文件失败: {:?} -> {:?}", assets, output));
    println!("已复制: {:?} -> {:?}", assets, output);

    // 告诉Cargo：如果assets目录下的so文件变化，重新运行构建脚本
    println!("cargo:rerun-if-changed=assets/");
}
