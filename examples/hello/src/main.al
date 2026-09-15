use std.io.{Writer, write_str, register_io};
use std.di.Container;

function main(): i32 {
    let di = Container();
    register_io(di);

    let out: Writer = di.get<Writer>();

    match write_str(out, "Hello, world!\n") {
        Ok(_) => {
            return 0;
        }
        Err(_) => {
            return 1;
        }
    }
}
