use prost_build::Config;
use std::fs;
use std::path::{Path, PathBuf};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut root_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    root_dir.pop();
    root_dir.pop();
    root_dir.push("messages");
    let root_dir = root_dir.as_path();

    let proto_files = find_proto_files(root_dir);

    let mut config = Config::new();
    let out_dir = Path::new("src/messages");
    fs::create_dir_all(out_dir)?;
    config.out_dir(out_dir);

    config.compile_protos(proto_files.as_slice(), &[root_dir])?;
    Ok(())
}

fn find_proto_files(dir: &Path) -> Vec<String> {
    let mut proto_files = Vec::new();
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries {
            if let Ok(entry) = entry {
                let path = entry.path();
                if path.is_dir() {
                    // 递归查找子目录
                    proto_files.extend(find_proto_files(&path));
                } else if let Some(ext) = path.extension() {
                    if ext == "proto" {
                        if let Some(file_path) = path.to_str() {
                            proto_files.push(file_path.to_string());
                        }
                    }
                }
            }
        }
    }
    proto_files
}
