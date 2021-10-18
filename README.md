# RoutesRumours
simulate migration route dynamics dependent on spread of information

## Requirements

* Julia >= 1.x 
* Distributions
* Parameters
* ArgParse
* JSON
* DataStructures
* MacroTools
* StaticArrays

optional (GUI):

* SimpleDirectMediaLayer  (>= 0.3.0)


## Running the simulation

In the package directory run:


```
julia run.jl [param file] [arguments...]
```

or, with gui:


```
julia run_gui.jl [param file] [arguments...]
```


In both cases the parameter file *has* to be given as the first argument. If it is not specified the program expects a file `params.jl` in the current directory. 

`--help` gives a full list of options with explanations.

### Maps

Maps in JSON format can be loaded using `-m <map file>`. Where `<map file>` is the name of the JSON file to be loaded, including relative paths if necessary (e.g. `../mediterranean.json`).


### Scenarios

Scenarios can be loaded using `-s <scenario> [options]`. `<scenario>` in this case is the name of the scenario file *including relative paths but without the .jl file ending* (there were good reasons to do it like that at some point...).

Scenarios can take parameters. These have to follow the scenario name and *have to be given as a single string*.

### Running from a different directory

To run the simulation from a different directory Julia's load path has to be set correctly. On Unix-like systems the easiest way to do this is by setting the environment variable directly. So, to run the simulation from a directory parallel to `rgct_data`, for example, the command would look like this:

```bash
JULIA_LOAD_PATH=$JULIA_LOAD_PATH:../rgct_data julia ../rgct_data/run.jl
```

### Example

Assuming a directory structure like this:

```
--- rgct_data/
 |
 |- params.jl
 |
 |- map_med1.json
 |
 |- mediterranean.jl
 |
 \- run1/
```

starting the simulation out of directory `run1` using parameter file, scenario and map from the parent directory and limiting run time to 500 time steps would look like this:

```bash
JULIA_LOAD_PATH=$JULIA_LOAD_PATH:../rgct_data julia ../rgct_data/run.jl ../params.jl -m ../map_med1.json -s ../mediterranean '--wait 10 --warmup 100 --int 0.01 0.077 0.153 0.428 0.389 --risks 0.01 0.023 0.020 0.029 0.048'  -t 500
```

## Output

The simulation produces a number of different outputs:

* `stdout` - the current time step
* `log.txt` - comprehensive data for each time step in TSV format
* `cities.txt` - a list of all cities and some accompanying data *at the end* of the simulation in TSV format
* `links.txt` - a list of all links and some accompanying data *at the end* of the simulation in TSV format
* `params_used.jl` - the parameter values used by the simulation in parameter file format

