# Rservex

`Rservex` is an under-development client for [Rserve](https://www.rforge.net/Rserve/index.html). 
Aiming to enable the R <--> Elixir interoperation.

`Rservex` is Heavily inspired in [Erserve](https://github.com/del/erserve)

## Current State

Currentle `Rservex` can:

 - Create a connection
 - Close a connection
 - Send a command and receives str responses

## Example

In R:
```r
library(Rserve)
Rserve()
```

In Elixir:
```elixir
iex(1)> conn = Rservex.open()                  

iex(2)> Rservex.eval(conn, "'Hello World'")                  
{:xt_arr_str, ["Hello World"]}

iex(3)> Rservex.eval(conn, "c('Hello', 'World')")
{:xt_arr_str, ["Hello", "World"]}

iex(4)> Rservex.eval(conn, "library(Pmetrics)") 
{:xt_arr_str,
 ["rjson", "Pmetrics", "stats", "graphics", "grDevices", "utils", "datasets",
  "methods", "base", ""]} 
```

## Installation

`rservex` is [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rservex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rservex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). The docs can
be found at [https://hexdocs.pm/rservex](https://hexdocs.pm/rservex).

