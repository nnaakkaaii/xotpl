{{ define "enum" }}
{{- $e := .Data -}}
// {{ $e.GoName }} is the '{{ $e.SQLName }}' enum type from schema '{{ schema }}'.
type {{ $e.GoName }} uint16

// {{ $e.GoName }} values.
const (
{{ range $e.Values -}}
	// {{ $e.GoName }}{{ .GoName }} is the '{{ .SQLName }}' {{ $e.SQLName }}.
	{{ $e.GoName }}{{ .GoName }} {{ $e.GoName }} = {{ .ConstValue }}
{{ end -}}
)

// String satisfies the [fmt.Stringer] interface.
func ({{ short $e.GoName }} {{ $e.GoName }}) String() string {
	switch {{ short $e.GoName }} {
{{ range $e.Values -}}
	case {{ $e.GoName }}{{ .GoName }}:
		return "{{ .SQLName }}"
{{ end -}}
	}
	return fmt.Sprintf("{{ $e.GoName }}(%d)", {{ short $e.GoName }})
}

// MarshalText marshals [{{ $e.GoName }}] into text.
func ({{ short $e.GoName }} {{ $e.GoName }}) MarshalText() ([]byte, error) {
	return []byte({{ short $e.GoName }}.String()), nil
}

// UnmarshalText unmarshals [{{ $e.GoName }}] from text.
func ({{ short $e.GoName }} *{{ $e.GoName }}) UnmarshalText(buf []byte) error {
	switch str := string(buf); str {
{{ range $e.Values -}}
	case "{{ .SQLName }}":
		*{{ short $e.GoName }} = {{ $e.GoName }}{{ .GoName }}
{{ end -}}
	default:
		return ErrInvalid{{ $e.GoName }}(str)
	}
	return nil
}

// Value satisfies the [driver.Valuer] interface.
func ({{ short $e.GoName }} {{ $e.GoName }}) Value() (driver.Value, error) {
	return {{ short $e.GoName }}.String(), nil
}

// Scan satisfies the [sql.Scanner] interface.
func ({{ short $e.GoName }} *{{ $e.GoName }}) Scan(v interface{}) error {
	switch x := v.(type) {
	case []byte:
		return {{ short $e.GoName }}.UnmarshalText(x)
	case string:
		return {{ short $e.GoName }}.UnmarshalText([]byte(x))
	}
	return ErrInvalid{{ $e.GoName }}(fmt.Sprintf("%T", v))
}

{{ $nullName := (printf "%s%s" "Null" $e.GoName) -}}
{{- $nullShort := (short $nullName) -}}
// {{ $nullName }} represents a null '{{ $e.SQLName }}' enum for schema '{{ schema }}'.
type {{ $nullName }} struct {
	{{ $e.GoName }} {{ $e.GoName }}
	// Valid is true if [{{ $e.GoName }}] is not null.
	Valid bool
}

// Value satisfies the [driver.Valuer] interface.
func ({{ $nullShort }} {{ $nullName }}) Value() (driver.Value, error) {
	if !{{ $nullShort }}.Valid {
		return nil, nil
	}
	return {{ $nullShort }}.{{ $e.GoName }}.Value()
}

// Scan satisfies the [sql.Scanner] interface.
func ({{ $nullShort }} *{{ $nullName }}) Scan(v interface{}) error {
	if v == nil {
		{{ $nullShort }}.{{ $e.GoName }}, {{ $nullShort }}.Valid = 0, false
		return nil
	}
	err := {{ $nullShort }}.{{ $e.GoName }}.Scan(v)
	{{ $nullShort }}.Valid = err == nil
	return err
}

// ErrInvalid{{ $e.GoName }} is the invalid [{{ $e.GoName }}] error.
type ErrInvalid{{ $e.GoName }} string

// Error satisfies the error interface.
func (err ErrInvalid{{ $e.GoName }}) Error() string {
	return fmt.Sprintf("invalid {{ $e.GoName }}(%s)", string(err))
}
{{ end }}

{{ define "foreignkey" }}
{{- $k := .Data -}}
// {{ func_name_context $k }} returns the {{ $k.RefTable }} associated with the [{{ $k.Table.GoName }}]'s ({{ names "" $k.Fields }}).
//
// Generated from foreign key '{{ $k.SQLName }}'.
{{ recv_context $k.Table $k }} {
	return {{ foreign_key_context $k }}
}
{{- if context_both }}

// {{ func_name $k }} returns the {{ $k.RefTable }} associated with the {{ $k.Table }}'s ({{ names "" $k.Fields }}).
//
// Generated from foreign key '{{ $k.SQLName }}'.
{{ recv $k.Table $k }} {
	return {{ foreign_key $k }}
}
{{- end }}
{{ end }}

{{ define "index" }}
{{- $i := .Data -}}
// {{ func_name_context $i }} retrieves a row from '{{ schema $i.Table.SQLName }}' as a [{{ $i.Table.GoName }}].
//
// Generated from index '{{ $i.SQLName }}'.
{{ func_context $i }} {
	// query
	{{ sqlstr "index" $i }}
	// run
	logf(sqlstr, {{ params $i.Fields false }})
{{- if $i.IsUnique }}
	{{ short $i.Table }} := {{ $i.Table.GoName }}{}
	if err := {{ db "QueryRow"  $i }}.Scan({{ names (print "&" (short $i.Table) ".") $i.Table }}); err != nil {
		return nil, logerror(err)
	}
	return &{{ short $i.Table }}, nil
{{- else }}
	rows, err := {{ db "Query" $i }}
	if err != nil {
		return nil, logerror(err)
	}
	defer rows.Close()
	// process
	var res []*{{ $i.Table.GoName }}
	for rows.Next() {
		{{ short $i.Table }} := {{ $i.Table.GoName }}{}
		// scan
		if err := rows.Scan({{ names_ignore (print "&" (short $i.Table) ".")  $i.Table }}); err != nil {
			return nil, logerror(err)
		}
		res = append(res, &{{ short $i.Table }})
	}
	if err := rows.Err(); err != nil {
		return nil, logerror(err)
	}
	return res, nil
{{- end }}
}

{{ if context_both -}}
// {{ func_name $i }} retrieves a row from '{{ schema $i.Table.SQLName }}' as a [{{ $i.Table.GoName }}].
//
// Generated from index '{{ $i.SQLName }}'.
{{ func $i }} {
	return {{ func_name_context $i }}({{ names "" "context.Background()" "db" $i }})
}
{{- end }}

func ({{ short $i.Table }}r *{{ $i.Table.GoName }}XoRepository) Select{{ if $i.IsUnique }}One{{ else }}Many{{ end }}By{{ range $j, $f := $i.Fields }}{{ if $j }}And{{ end }}{{ $f.GoName }}{{ end }}(ctx context.Context, db QueryContext, {{ range $j, $f := $i.Fields }}{{ if $j }}, {{ end }}{{ $f.GoName }} {{ $f.Type }}{{ end }} {{ if not $i.IsUnique -}}, limit, offset *uint64 {{- end }}) ({{ if not $i.IsUnique -}} [] {{- end }} *{{- $i.Table.GoName }}, error) {
    eq := squirrel.Eq{
    {{- range $i.Fields }}
        {{ $i.Table.GoName}}{{ .GoName}}: {{ .GoName }},
    {{- end }}
    }
    {{ if $i.IsUnique }}
    query, params, err := squirrel.
        Select({{ $i.Table.GoName }}AllColumns...).
        From({{ $i.Table.GoName}}TableName).
        Where(eq).
        ToSql()
    {{ else }}
    sql := squirrel.
        Select({{ $i.Table.GoName }}AllColumns...).
        From({{ $i.Table.GoName}}TableName).
        Where(eq)
    if limit != nil {
        sql = sql.Limit(*limit)
    }
    if offset != nil {
        sql = sql.Offset(*offset)
    }
    query, params, err := sql.ToSql()
    {{- end }}
    if err != nil {
        return nil, logerror(err)
    }

    {{- if $i.IsUnique }}
    return iterate{{ $i.Table.GoName }}(db.QueryRowContext(ctx, query, params...))
    {{- else }}
    rows, err := db.QueryContext(ctx, query, params...)
    if err != nil {
        return nil, logerror(err)
    }
    res := make([]*{{ $i.Table.GoName }}, 0)
    for rows.Next() {
        t, err := iterate{{ $i.Table.GoName }}(rows)
        if err != nil {
            return nil, logerror(err)
        }
        res = append(res, t)
    }
    return res, nil
    {{- end }}
}

{{end}}

{{ define "procs" }}
{{- $ps := .Data -}}
{{- range $p := $ps -}}
// {{ func_name_context $p }} calls the stored {{ $p.Type }} '{{ $p.Signature }}' on db.
{{ func_context $p }} {
{{- if and (driver "mysql") (eq $p.Type "procedure") (not $p.Void) }}
	// At the moment, the Go MySQL driver does not support stored procedures
	// with out parameters
	return {{ zero $p.Returns }}, fmt.Errorf("unsupported")
{{- else }}
	// call {{ schema $p.SQLName }}
	{{ sqlstr "proc" $p }}
	// run
{{- if not $p.Void }}
{{- range $p.Returns }}
	var {{ check_name .GoName }} {{ type .Type }}
{{- end }}
	logf(sqlstr, {{ params $p.Params false }})
{{- if and (driver "sqlserver" "oracle") (eq $p.Type "procedure")}}
	if _, err := {{ db_named "Exec" $p }}; err != nil {
{{- else }}
	if err := {{ db "QueryRow" $p }}.Scan({{ names "&" $p.Returns }}); err != nil {
{{- end }}
		return {{ zero $p.Returns }}, logerror(err)
	}
	return {{ range $p.Returns }}{{ check_name .GoName }}, {{ end }}nil
{{- else }}
	logf(sqlstr)
{{- if driver "sqlserver" "oracle" }}
	if _, err := {{ db_named "Exec" $p }}; err != nil {
{{- else }}
	if _, err := {{ db "Exec" $p }}; err != nil {
{{- end }}
		return logerror(err)
	}
	return nil
{{- end }}
{{- end }}
}

{{ if context_both -}}
// {{ func_name $p }} calls the {{ $p.Type }} '{{ $p.Signature }}' on db.
{{ func $p }} {
	return {{ func_name_context $p }}({{ names_all "" "context.Background()" "db" $p.Params }})
}
{{- end -}}
{{- end }}
{{ end }}

{{ define "typedef" }}
{{- $t := .Data -}}
const {{ $t.GoName }}TableName = "{{ $t.SQLName }}"
const (
{{- range $t.Fields -}}
    {{ $t.GoName}}{{ .GoName}} = "{{ .SQLName }}"
{{ end }}
)
var {{ $t.GoName }}AllColumns = []string{
{{- range $t.Fields -}}
    {{ $t.GoName}}{{ .GoName}},
{{ end }}
}
var {{ $t.GoName }}Columns = []string{
{{- range $t.Fields -}}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    {{ $t.GoName}}{{ .GoName}},
    {{- end -}}
{{ end }}
}
var {{ $t.GoName }}PrimaryKeys = []string{
{{- range $t.PrimaryKeys -}}
    {{ $t.GoName}}{{ .GoName}},
{{ end }}
}

// {{ $t.GoName }} represents a row from '{{ schema $t.SQLName }}'.
type {{ $t.GoName }} struct {
{{ range $t.Fields -}}
	{{ .GoName }} {{ .Type }} `db:"{{ .SQLName }}" json:"{{ .SQLName }}"`
{{ end }}
}

func ({{ short $t }} *{{ $t.GoName }}) Ptrs() []interface{} {
    return []interface{}{
{{- range $t.Fields }}
        &{{ short $t }}.{{ .GoName }},
{{- end }}
    }
}

func ({{ short $t }} *{{ $t.GoName }}) ColumnsToPtrs(cols []string, customPtrs map[string]interface{}) ([]interface{}, error) {
    ret := make([]interface{}, 0, len(cols))
    for _, col := range cols {
        if ptr, ok := customPtrs[col]; ok {
            ret = append(ret, ptr)
            continue
        }

        switch col {
{{- range $t.Fields }}
        case {{ $t.GoName}}{{ .GoName}}:
            ret = append(ret, &{{ short $t }}.{{ .GoName }})
{{- end }}
        default:
            return nil, fmt.Errorf("unknown column %s", col)
        }
    }
    return ret, nil
}

func ({{ short $t }} *{{ $t.GoName }}) ColumnsToValues(cols []string) ([]interface{}, error) {
    ret := make([]interface{}, 0, len(cols))
    for _, col := range cols {
        switch col {
{{- range $t.Fields }}
        case {{ $t.GoName}}{{ .GoName}}:
            ret = append(ret, {{ short $t }}.{{ .GoName }})
{{- end }}
        default:
            return nil, fmt.Errorf("unknown column %s", col)
        }
    }
    return ret, nil
}

func iterate{{ $t.GoName }}(sc interface{ Scan(...interface{}) error}) (*{{ $t.GoName }}, error) {
    t := {{ $t.GoName }}{}
    if err := sc.Scan(t.Ptrs()...); err != nil {
        return nil, logerror(err)
    }
    return &t, nil
}

type {{ $t.GoName }}XoRepository struct {}

func New{{ $t.GoName }}XoRepository() *{{ $t.GoName }}XoRepository {
    return &{{ $t.GoName }}XoRepository{}
}

type Select{{ $t.GoName }}Options struct {
{{- range $t.Fields }}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    {{ .GoName}} *{{ .Type }}
    {{- end }}
{{- end }}
}

func ({{ short $t }}r *{{ $t.GoName }}XoRepository) Select(ctx context.Context, db QueryContext, opts Select{{ $t.GoName }}Options) (*{{ $t.GoName }}, error) {
    and := squirrel.And{}
    {{- range $t.Fields }}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    if opts.{{ .GoName }} != nil {
        and = append(and, squirrel.Eq{ {{ $t.GoName }}{{ .GoName }}: *opts.{{ .GoName }}})
    }
    {{- end }}
    {{- end }}

    query, params, err := squirrel.
        Select({{ $t.GoName }}AllColumns...).
        From({{ $t.GoName }}TableName).
        Where(and).
        ToSql()
    if err != nil {
        return nil, logerror(err)
    }

    return iterate{{ $t.GoName }}(db.QueryRowContext(ctx, query, params...))
}

type List{{ $t.GoName }}Options struct {
{{- range $t.Fields }}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    {{ .GoName}} []{{ .Type }}
    {{ .GoName}}Contains []{{ .Type }}
    {{ .GoName}}Lt []{{ .Type }}
    {{ .GoName}}Geq []{{ .Type }}
    {{ .GoName}}Leq []{{ .Type }}
    {{ .GoName}}Gt []{{ .Type }}
    {{- end }}
{{- end }}
    Limit *uint64
    Offset *uint64
}

func ({{ short $t }}r *{{ $t.GoName }}XoRepository) List(ctx context.Context, db QueryContext, opts List{{ $t.GoName }}Options) ([]*{{ $t.GoName }}, error) {
    and := squirrel.And{}
    {{- range $t.Fields }}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    if len(opts.{{ .GoName }}) > 0 {
        and = append(and, squirrel.Eq{ {{ $t.GoName }}{{ .GoName }}: opts.{{ .GoName }}})
    }
    {{- if eq .Type "string" }}
    if len(opts.{{ .GoName }}Contains) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Contains {
            or = append(or, squirrel.Like{ {{ $t.GoName}}{{ .GoName}}: fmt.Sprintf("%%%s%%", v)})
        }
        and = append(and, or)
    }
    {{- end }}
    if len(opts.{{ .GoName }}Lt) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Lt {
            and = append(and, squirrel.Lt{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Leq) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Leq {
            and = append(and, squirrel.LtOrEq{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Geq) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Geq {
            and = append(and, squirrel.GtOrEq{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Gt) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Gt {
            and = append(and, squirrel.Gt{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    {{- end }}
    {{- end }}

    sql := squirrel.
        Select({{ $t.GoName }}AllColumns...).
        From({{ $t.GoName }}TableName).
        Where(and)

    if opts.Limit != nil {
        sql = sql.Limit(*opts.Limit)
    }
    if opts.Offset != nil {
        sql = sql.Offset(*opts.Offset)
    }

    query, params, err := sql.ToSql()
    if err != nil {
        return nil, logerror(err)
    }

    rows, err := db.QueryContext(ctx, query, params...)
    if err != nil {
        return nil, logerror(err)
    }
    res := make([]*{{ $t.GoName }}, 0)
    for rows.Next() {
        t, err := iterate{{ $t.GoName }}(rows)
        if err != nil {
            return nil, logerror(err)
        }
        res = append(res, t)
    }
    return res, nil
}

func ({{ short $t }}r *{{ $t.GoName }}XoRepository) Count(ctx context.Context, db QueryContext, opts List{{ $t.GoName }}Options) (uint64, error) {
    and := squirrel.And{}
    {{- range $t.Fields }}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    if len(opts.{{ .GoName }}) > 0 {
        and = append(and, squirrel.Eq{ {{ $t.GoName }}{{ .GoName }}: opts.{{ .GoName }}})
    }
    {{- if eq .Type "string" }}
    if len(opts.{{ .GoName }}Contains) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Contains {
            or = append(or, squirrel.Like{ {{ $t.GoName}}{{ .GoName}}: fmt.Sprintf("%%%s%%", v)})
        }
        and = append(and, or)
    }
    {{- end }}
    if len(opts.{{ .GoName }}Lt) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Lt {
            and = append(and, squirrel.Lt{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Leq) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Leq {
            and = append(and, squirrel.LtOrEq{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Geq) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Geq {
            and = append(and, squirrel.GtOrEq{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Gt) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Gt {
            and = append(and, squirrel.Gt{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    {{- end }}
    {{- end }}

    query, params, err := squirrel.
        Select("COUNT(1)").
        From({{ $t.GoName }}TableName).
        Where(and).
        ToSql()
    if err != nil {
        return 0, logerror(err)
    }

    var count uint64
    if err = db.QueryRowContext(ctx, query, params...).Scan(&count); err != nil {
		return 0, logerror(err)
	}

	return count, nil
}

{{ if $t.PrimaryKeys -}}

func ({{ short $t }}r *{{ $t.GoName }}XoRepository) Insert(ctx context.Context, db QueryContext, records []*{{ $t.GoName }}, ignore []string) error {
    if len(records) == 0 {
        return nil
    }

    var columns []string
    for _, col := range {{ $t.GoName }}Columns {
        if !slices.Contains(ignore, col) {
            columns = append(columns, col)
        }
    }
    sql := squirrel.
        Insert({{ $t.GoName }}TableName).
        Columns(columns...)
    for _, record := range records {
        v, err := record.ColumnsToValues(columns)
        if err != nil {
            return logerror(err)
        }
        sql = sql.Values(v...)
    }
    query, params, err := sql.ToSql()

    if err != nil {
        return logerror(err)
    }

    _, err = db.ExecContext(ctx, query, params...)
    if err != nil {
        return logerror(err)
    }
    return nil
}

func ({{ short $t }}r *{{ $t.GoName }}XoRepository) Upsert(ctx context.Context, db QueryContext, records []*{{ $t.GoName }}, ignore []string) error {
    if len(records) == 0 {
        return nil
    }

    var columns []string
    for _, col := range {{ $t.GoName }}Columns {
        if !slices.Contains(ignore, col) {
            columns = append(columns, col)
        }
    }
    sql := squirrel.
        Insert({{ $t.GoName }}TableName).
        Columns(columns...)
    for _, record := range records {
        v, err := record.ColumnsToValues(columns)
        if err != nil {
            return logerror(err)
        }
        sql = sql.Values(v...)
    }

    var columnsWithoutPrimaryKeys []string
    for _, col := range columns {
        if !slices.Contains({{ $t.GoName }}PrimaryKeys, col) {
            columnsWithoutPrimaryKeys = append(columnsWithoutPrimaryKeys, fmt.Sprintf("%s = VALUES(%s)", col, col))
        }
    }
    sql = sql.Suffix("ON DUPLICATE KEY UPDATE " + strings.Join(columnsWithoutPrimaryKeys, ", "))

    query, params, err := sql.ToSql()

    if err != nil {
        return logerror(err)
    }

    _, err = db.ExecContext(ctx, query, params...)
    if err != nil {
        return logerror(err)
    }
    return nil
}

type Delete{{ $t.GoName }}Options struct {
{{- range $t.Fields }}
    {{ .GoName}} []{{ .Type }}
    {{ .GoName}}Contains []{{ .Type }}
    {{ .GoName}}Lt []{{ .Type }}
    {{ .GoName}}Geq []{{ .Type }}
    {{ .GoName}}Leq []{{ .Type }}
    {{ .GoName}}Gt []{{ .Type }}
{{- end }}
}

func ({{ short $t }}r *{{ $t.GoName }}XoRepository) Delete(ctx context.Context, db QueryContext, opts Delete{{ $t.GoName }}Options) error {
    and := squirrel.And{}
    {{- range $t.Fields }}
    {{- if and (ne .SQLName "created_at") (ne .SQLName "updated_at") }}
    if len(opts.{{ .GoName }}) > 0 {
        and = append(and, squirrel.Eq{ {{ $t.GoName}}{{ .GoName}}: opts.{{ .GoName }}})
    }
    {{- if eq .Type "string" }}
    if len(opts.{{ .GoName }}Contains) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Contains {
            or = append(or, squirrel.Like{ {{ $t.GoName}}{{ .GoName}}: fmt.Sprintf("%%%s%%", v)})    
        }
        and = append(and, or)
    }
    {{- end }}
    if len(opts.{{ .GoName }}Lt) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Lt {
            and = append(and, squirrel.Lt{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Leq) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Leq {
            and = append(and, squirrel.LtOrEq{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Geq) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Geq {
            and = append(and, squirrel.GtOrEq{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    if len(opts.{{ .GoName }}Gt) > 0 {
        or := squirrel.Or{}
        for _, v := range opts.{{ .GoName }}Gt {
            and = append(and, squirrel.Gt{ {{ $t.GoName}}{{ .GoName}}: v})
        }
        and = append(and, or)
    }
    {{- end }}
    {{- end }}

    query, params, err := squirrel.
        Delete({{ $t.GoName }}TableName).
        Where(and).
        ToSql()
    if err != nil {
        return logerror(err)
    }

    _, err = db.ExecContext(ctx, query, params...)
    if err != nil {
        return logerror(err)
    }
    return nil
}

// {{ func_name_context "Insert" }} inserts the [{{ $t.GoName }}] to the database.
{{ recv_context $t "Insert" }} {
{{ if $t.Manual -}}
	// insert (manual)
	{{ sqlstr "insert_manual" $t }}
	// run
	{{ logf $t }}
	if _, err := {{ db_prefix "Exec" false $t }}; err != nil {
		return logerror(err)
	}
{{- else -}}
	// insert (primary key generated and returned by database)
	{{ sqlstr "insert" $t }}
	// run
	{{ logf $t $t.PrimaryKeys }}
	res, err := {{ db_prefix "Exec" true $t }}
	if err != nil {
		return logerror(err)
	}
	// retrieve id
	id, err := res.LastInsertId()
	if err != nil {
		return logerror(err)
	}
	// set primary key
	{{ short $t }}.{{ (index $t.PrimaryKeys 0).GoName }} = {{ (index $t.PrimaryKeys 0).Type }}(id)
{{- end }}
	return nil
}

{{ if context_both -}}
// Insert inserts the [{{ $t.GoName }}] to the database.
{{ recv $t "Insert" }} {
	return {{ short $t }}.InsertContext(context.Background(), db)
}
{{- end }}


{{ if eq (len $t.Fields) (len $t.PrimaryKeys) -}}
// ------ NOTE: Update statements omitted due to lack of fields other than primary key ------
{{- else -}}
// {{ func_name_context "Update" }} updates a [{{ $t.GoName }}] in the database.
{{ recv_context $t "Update" }} {
	// update with primary key
	{{ sqlstr "update" $t }}
	// run
	{{ logf_update $t }}
	if _, err := {{ db_update "Exec" $t }}; err != nil {
		return logerror(err)
	}
	return nil
}

{{ if context_both -}}
// Update updates a [{{ $t.GoName }}] in the database.
{{ recv $t "Update" }} {
	return {{ short $t }}.UpdateContext(context.Background(), db)
}
{{- end }}

// {{ func_name_context "Upsert" }} performs an upsert for [{{ $t.GoName }}].
{{ recv_context $t "Upsert" }} {
	// upsert
	{{ sqlstr "upsert" $t }}
	// run
	{{ logf $t }}
	if _, err := {{ db_prefix "Exec" false $t }}; err != nil {
		return logerror(err)
	}
	return nil
}

{{ if context_both -}}
// Upsert performs an upsert for [{{ $t.GoName }}].
{{ recv $t "Upsert" }} {
	return {{ short $t }}.UpsertContext(context.Background(), db)
}
{{- end -}}
{{- end }}

// {{ func_name_context "Delete" }} deletes the [{{ $t.GoName }}] from the database.
{{ recv_context $t "Delete" }} {
{{ if eq (len $t.PrimaryKeys) 1 -}}
	// delete with single primary key
	{{ sqlstr "delete" $t }}
	// run
	{{ logf_pkeys $t }}
	if _, err := {{ db "Exec" (print (short $t) "." (index $t.PrimaryKeys 0).GoName) }}; err != nil {
		return logerror(err)
	}
{{- else -}}
	// delete with composite primary key
	{{ sqlstr "delete" $t }}
	// run
	{{ logf_pkeys $t }}
	if _, err := {{ db "Exec" (names (print (short $t) ".") $t.PrimaryKeys) }}; err != nil {
		return logerror(err)
	}
{{- end }}
	return nil
}

{{ if context_both -}}
// Delete deletes the [{{ $t.GoName }}] from the database.
{{ recv $t "Delete" }} {
	return {{ short $t }}.DeleteContext(context.Background(), db)
}
{{- end -}}
{{- end }}

{{ end }}