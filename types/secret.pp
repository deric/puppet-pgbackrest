# Either plain-text password or Sensitive string
type Pgbackrest::Secret = Variant[String,Sensitive[String]]
