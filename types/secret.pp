# @summary Either a plain-text password or a Sensitive string
type Pgbackrest::Secret = Variant[String,Sensitive[String]]
