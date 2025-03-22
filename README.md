# Octave Jupyter Notebook package

> **This package is already included into Octave core.**
> The function of this package `jupyter_notebook` exists in Octave version 7 and newer: <https://octave.org/NEWS-7.html#general-improvements>.

<img src="doc/icon.png" alt="logo" width="65%" style="margin-left:auto; margin-right:auto; display:block;"/>

A package to run and fill Jupyter Notebooks within GNU Octave.

The package supports filling both textual and graphical outputs.

## Installation
From the Octave command-line:
```
pkg install "https://github.com/gnu-octave/pkg-jupyter-notebook/archive/v1.3.0.tar.gz"
```

## jupyter_notebook

```
notebook_object = jupyter_notebook (notebook_filename, options)
```

Run and fill the Jupyter Notebook in file `notebook_filename` from
within GNU Octave.

Both text and graphical Octave outputs are supported.

This class has a public property `notebook` which is a structure
representing the JSON-decoded Jupyter Notebook.  This property is
intentionally public to enable advanced notebook manipulations.

**Note:** Jupyter Notebook versions (`nbformat`) lower than 4.0 are not
supported.

The optional second argument `options` is a struct with fields:

* `tmpdir` to set the temporary working directory.

## plot magic

`%plot` magic is supported with the following settings:

* `%plot -f <format>` or `%plot --format <format>`: specifies the
  image storage format.  Supported formats are:
    * PNG (default)
    * SVG (Note: If SVG images do not appear in the notebook,
           it is most related to the Jupyter Notebook security
           mechanism and explicitly "trusting" them is necessary).
    * JPG

* `%plot -r <number>` or `%plot --resolution <number>`: specifies the image resolution.

* `%plot -w <number>` or `%plot --width <number>`: specifies the image width.

* `%plot -h <number>` or `%plot --height <number>`: specifies the image height.

## Methods

The `jupyter_notebook` class supports the following methods.

### `run (cell_index)`

Run the Jupyter Notebook cell with index `cell_index`
and eventually replace previous output cells in the object.

The first Jupyter Notebook cell has the index 1.

**Note:** The code evaluation of the Jupyter Notebook cells is done
in a separate Jupyter Notebook context.  Thus, currently open
figures and workspace variables won't be affected by executing
this function.  However, current workspace variables cannot be
accessed either.

### `run_all ()`

Run all Jupyter Notebook cells and eventually replace previous
output cells in the object.

**Note:** The code evaluation of the Jupyter Notebook cells is done
in a separate Jupyter Notebook context.  Thus, currently open
figures and workspace variables won't be affected by executing
this function.  However, current workspace variables cannot be
accessed either.

### `generate_notebook (notebook_file_name)`

Write the Jupyter Notebook stored in the `notebook`
attribute to `notebook_file_name`.

The `notebook` attribute is encoded to JSON text.

### `generate_octave_script (script_file_name)`

Write an Octave script that has the contents of the Jupyter Notebook
stored in the `notebook` attribute to `script_file_name`.

Non-code cells are generated as block comments.

## Examples:

The outputs of the following examples are shown using this notebook:
<img src="doc/before-running.png" alt="example-notebook" width="100%" />

### Run all cells and generate the filled notebook

```
## Instantiate an object from the notebook file
notebook = jupyter_notebook ("myNotebook.ipynb")
=> notebook =

    <object jupyter_notebook>

## Run the code and embed the results in the notebook attribute
notebook.run_all()

## Generate the new notebook by overwriting the original notebook
notebook.generate_notebook ("myNotebook.ipynb")
```

This is the generated notebook:
<img src="doc/runAll.png" alt="example-1" width="100%" />

### Run the third cell and generate the filled notebook

```
## Instantiate an object from the notebook file
notebook = jupyter_notebook ("myNotebook.ipynb")
=> notebook =

    <object jupyter_notebook>

## Run the code and embed the results in the notebook attribute
notebook.run(3)

## Generate the new notebook in a new file
notebook.generate_notebook ("myNewNotebook.ipynb")
```

This is the generated notebook:
<img src="doc/run.png" alt="example-2" width="100%" />

### Generate an Octave script from a notebook

```
## Instantiate an object from the notebook file
notebook = jupyter_notebook ("myNotebook.ipynb")
=> notebook =

    <object jupyter_notebook>

## Generate the octave script
notebook.generate_octave_script ("myScript.m")
```

This is the generated script:
<img src="doc/octaveScript.png" alt="example-3" width="100%" />
