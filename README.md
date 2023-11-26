# Julia mixed models demo

## Setup

- Download Julia (via juliaup)

- Install Arrow.jl, DataFrames.jl, MixedModels.jl, and RCall.jl (and
  call `Pkg.build("RCall")`)

## Julia in RStudio

### Keyboard shortcuts

- “Send Selection to Terminal”: Sends the highlighted selection (or
  contents of the current line) to terminal. If the active terminal is a
  Julia REPL, it essentially executes Julia code

- “Move Focus to Terminal”: Switches to the terminal tab in the console
  panel.

- “Move Focus to Console”: Switches to the console tab in the console
  panel.

### Creating and opening a `.jl` file

The dropdown menu for creating a new blank file is missing the option to
create a Julia file. But you can programmatically create and open a
`.jl` file from R:

``` r
file.create("foo.jl")
file.edit("foo.jl")
```

## Poorman’s interoperability

### Between R sessions - read/write RDS file as bridge:

- Write:

``` r
tmp <- tempfile(fileext = ".rds")
saveRDS(mtcars, tmp)
# writeClipboard()
```

- Read:

``` r
readRDS("...") # readClipboard()
```

### From R REPL to Julia (`rcopy` or `convert()`):

``` julia
robj = R"1 + 1"
rcopy(robj) # or below for more control
convert(Int, robj)
```

### From Julia to R REPL (interpolation with `$()`):

``` julia
jlobj = 1 + 1
R"$(jlobj)"
```

### Transferring variables

Once defined, R/Julia variables can be transferred with `@rput` and
`@rget`:

``` julia
@rput jlobj;
R"jlobj"
R"jlobj2 <- jlobj + 1";
@rget jlobj2;
jlobj2
```

### Special note for data frames

Use Arrow for data transfer (usually, R to Julia):

``` r
library(arrow)
tmp_arrow <- tempfile(fileext = ".arrow")
write_feather(mtcars, tmp_arrow)
# writeClipboard(tmp_arrow)
```

``` julia
using Arrow, DataFrames
data = Arrow.Table("...") # clipboard()
DataFrame(data)
```
