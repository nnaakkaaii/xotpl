# xotpl

This repository provides template files (`tpl`) used for code generation with the `xo` tool. These templates facilitate the automatic generation of Go code from SQL database schemas, streamlining database interactions in your application.

## Usage

To generate code, ensure you are connected to a MySQL database and execute the following command:

```bash
xo schema mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DATABASE}?parseTime=true -o <relative output path> --src <relative path to this directory (xotpl)>
```

This command will generate code in the specified output directory based on the provided database schema and the template files from this repository.
