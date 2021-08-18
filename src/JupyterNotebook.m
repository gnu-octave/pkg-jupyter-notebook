## Copyright (C) 2021 The Octave Project Developers
##
## This program is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see
## <https://www.gnu.org/licenses/>.


classdef JupyterNotebook < handle

  ## -*- texinfo -*-
  ## @deftypefn  {} {@var{notebook} =} JupyterNotebook (@var{notebookFileName})
  ##
  ## Run and fill the Jupyter Notebook in @var{notebookFileName}
  ## within GNU Octave.
  ##
  ## Support filling both textual and graphical outputs.
  ##
  ## This classdef has a public attribute @qcode{notebook} which is
  ## the struct that we get from decoding the JSON text that represents
  ## the notebook. This attribute is left public on purpose in case
  ## the user wants to manipulate the notebook more.
  ##
  ## Note: @qcode{nbformat} versions lower than 4.0 are not supported.
  ##
  ## @qcode{%plot} magic is supported with the following settings:
  ## @itemize @bullet
  ## @item
  ## "%plot -f <format>" or "%plot --format <format>": this setting allows you
  ## to specify the format of the images generated from plotting. the supported
  ## formats are:
  ##
  ## @itemize @minus
  ## @item
  ## PNG (default format)
  ##
  ## @item
  ## SVG (Note: SVG images may not appear in the notebook. To view them,
  ## trust the notebook).
  ##
  ## @item
  ## JPG
  ## @end itemize
  ##
  ## @item
  ## "%plot -r <number>" or "%plot --resolution <number>": this setting allows
  ## you to specify the resolution of the images generated from plotting.
  ##
  ## @item
  ## "%plot -w <number>" or "%plot --width <number>": this setting allows
  ## you to specify the width of the images generated from plotting.
  ##
  ## @item
  ## "%plot -h <number>" or "%plot --height <number>": this setting allows
  ## you to specify the height of the images generated from plotting.
  ## @end itemize
  ##
  ## Examples:
  ##
  ## @example
  ## @group
  ## ## Run all cells and generate the filled notebook
  ##
  ## ## Instantiate an object from the notebook file
  ## notebook = JupyterNotebook("myNotebook.ipynb")
  ##     @result{} notebook =
  ##
  ##         <object JupyterNotebook>
  ##
  ## ## Run the code and embed the results in the @qcode{notebook} attribute
  ## notebook.runAll()
  ## ## Generate the new notebook by overwriting the original notebook
  ## notebook.generateNotebook("myNotebook.ipynb")
  ## @end group
  ##
  ## @group
  ## ## Run the second cell and generate the filled notebook
  ##
  ## ## Instantiate an object from the notebook file
  ## notebook = JupyterNotebook("myNotebook.ipynb")
  ##     @result{} notebook =
  ##
  ##         <object JupyterNotebook>
  ##
  ## ## Run the code and embed the results in the @qcode{notebook} attribute
  ## notebook.run(2)
  ## ## Generate the new notebook in a new file
  ## notebook.generateNotebook("myNewNotebook.ipynb")
  ## @end group
  ##
  ## @group
  ## ## Generate an Octave script from a notebook
  ##
  ## ## Instantiate an object from the notebook file
  ## notebook = JupyterNotebook("myNotebook.ipynb")
  ##     @result{} notebook =
  ##
  ##         <object JupyterNotebook>
  ##
  ## ## Generate the octave script
  ## notebook.generateOctaveScript("myScript.m")
  ## @end group
  ## @end example
  ##
  ## @seealso{jsondecode, jsonencode}
  ## @end deftypefn

  properties

    notebook = struct()

  endproperties

  properties (Access = "private")

    context = struct("ans", "")

  endproperties

  methods

    function obj = JupyterNotebook (notebookFileName)

      if (nargin != 1)
        print_usage ();
      endif

      if (! (ischar (notebookFileName) && isrow (notebookFileName)))
        error ("JupyterNotebook: notebookFileName must be a string");
      endif

      obj.notebook = jsondecode (fileread (notebookFileName),
                                 "makeValidName", false);

      ## Validate the notebook's format according to nbformat: 4.0
      if (! (isfield (obj.notebook, "metadata") &&
             isfield (obj.notebook, "nbformat") &&
             isfield (obj.notebook, "nbformat_minor") &&
             isfield (obj.notebook, "cells")))
        error ("JupyterNotebook: not valid format for Jupyter notebooks");
      endif

      ## Issue a warning if the format is lower than 4.0
      if (obj.notebook.nbformat < 4)
        warning (["JupyterNotebook: nbformat versions lower than 4.0 are ", ...
                  "not supported"]);
      endif

      ## Handle the case if there is only one cell.
      ## Make "obj.notebook.cells" a cell of structs to match the format.
      if (numel (obj.notebook.cells) == 1)
        obj.notebook.cells = {obj.notebook.cells};
      endif

      ## Handle the case if the cells have the same keys.
      ## Make "obj.notebook.cells" a cell of structs instead of struct array
      ## to unify the indexing method.
      if (isstruct (obj.notebook.cells))
        obj.notebook.cells = num2cell (obj.notebook.cells);
      endif

      for i = 1:numel (obj.notebook.cells)
        if (! isfield (obj.notebook.cells{i}, "source"))
          error ("JupyterNotebook: cells must contain a \"source\" field");
        endif
        
        if (! isfield (obj.notebook.cells{i}, "cell_type"))
          error ("JupyterNotebook: cells must contain a \"cell_type\" field");
        endif
        
        ## Handle when null JSON values are decoded into empty arrays.
        if (isfield (obj.notebook.cells{i}, "execution_count")
            && numel (obj.notebook.cells{i}.execution_count) == 0)
          obj.notebook.cells{i}.execution_count = 1;
        endif
        
        ## Handle the case if there is only one output in the cell.
        ## Make the outputs of the cell a cell of structs to match the format.
        if (isfield (obj.notebook.cells{i}, "outputs")
            && numel (obj.notebook.cells{i}.outputs) == 1)
          obj.notebook.cells{i}.outputs = {obj.notebook.cells{i}.outputs};
        endif
      endfor

    endfunction


    function generateOctaveScript (obj, scriptFileName)

      ## -*- texinfo -*-
      ## @deftypefn {} {} generateOctaveScript (@var{scriptFileName})
      ##
      ## Write an Octave script that has the contents of the jupyter notebook
      ## stored in the @qcode{notebook} attribute to @var{scriptFileName}.
      ##
      ## Non code cells are generated as block comments.
      ##
      ## See @code{help JupyterNotebook} for examples.
      ##
      ## @end deftypefn

      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (scriptFileName) && isrow (scriptFileName)))
        error ("JupyterNotebook: scriptFileName must be a string");
      endif

      fhandle = fopen (scriptFileName, "w");

      for i = 1:numel (obj.notebook.cells)
        if (strcmp (obj.notebook.cells{i}.cell_type, "markdown"))
          fputs (fhandle, "\n#{\n");
        endif

        for k = 1:numel (obj.notebook.cells{i}.source)
          fputs (fhandle, obj.notebook.cells{i}.source{k});
        endfor

        if (strcmp (obj.notebook.cells{i}.cell_type, "markdown"))
          fputs (fhandle, "\n#}\n");
        endif
        fputs (fhandle, "\n");
      endfor
      fclose (fhandle);

    endfunction


    function generateNotebook (obj, notebookFileName)

      ## -*- texinfo -*-
      ## @deftypefn {} {} generateNotebook (@var{notebookFileName})
      ##
      ## Write the jupyter notebook stored in the @qcode{notebook}
      ## attribute to @var{notebookFileName}.
      ##
      ## The @qcode{notebook} attribute is encoded to JSON text.
      ##
      ## See @code{help JupyterNotebook} for examples.
      ##
      ## @end deftypefn

      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (notebookFileName) && isrow (notebookFileName)))
        error ("JupyterNotebook: notebookFileName must be a string");
      endif

      fhandle = fopen (notebookFileName, "w");

      fputs (fhandle, jsonencode (obj.notebook, "ConvertInfAndNaN", false,
                                  "PrettyPrint", true));

      fclose (fhandle);

    endfunction


    function run (obj, cell_index)

      ## -*- texinfo -*-
      ## @deftypefn {} {} run (@var{cell_index})
      ##
      ## Run the cell with index @var{cell_index} in the notebook. The
      ## results are embedded in the object.
      ##
      ## The evaluation of the code inside the notebook cells is done
      ## in a separate context. This context is loaded before running
      ## the code inside the cell and saved after running it.
      ##
      ## If the code produces figures, those figures are set hidden,
      ## saved in a temporary directory @qcode{__octave_jupyter_temp__}
      ## and removed after being embedded. The temporary directory is
      ## also removed after running the code.
      ##
      ## Your open figures won't be affected by the figures produced by
      ## the code in the notebook.
      ##
      ## See @code{help JupyterNotebook} for examples.
      ##
      ## @end deftypefn

      if (nargin != 2)
        print_usage ();
      endif

      if (! (isscalar (cell_index) && ! islogical (cell_index)
          && (mod (cell_index, 1) == 0) && (cell_index > 0)))
        error ("JupyterNotebook: cell_index must be a scalar positive integer");
      endif

      if (cell_index > length (obj.notebook.cells))
        error ("JupyterNotebook: cell_index is out of bound");
      endif

      if (! strcmp (obj.notebook.cells{cell_index}.cell_type, "code"))
        return;
      endif

      ## Remove previous outputs.
      obj.notebook.cells{cell_index}.outputs = {};

      if (isempty (obj.notebook.cells{cell_index}.source))
        return;
      endif

      ## Default values for printOptions.
      printOptions.imageFormat = "png";
      printOptions.resolution = "150";

      ## The default width and height in Jupyter notebook
      printOptions.width = "640";
      printOptions.height = "480";

      ## Parse "plot magic" commands.
      ## https://github.com/Calysto/metakernel/blob/master/metakernel/ ...
      ##   magics/README.md#plot
      for j = 1 : numel (obj.notebook.cells{cell_index}.source)
        if (strncmpi (obj.notebook.cells{cell_index}.source{j}, "%plot", 5))
          magics = strsplit (strtrim ( ...
            obj.notebook.cells{cell_index}.source{j}));
          for i = 1 : numel (magics)
            if (any (strcmp (magics{i}, {"-f", "--format"})) ...
                && (i < numel (magics)))
              printOptions.imageFormat = magics{i+1};
            endif
            if (any (strcmp (magics{i}, {"-r", "--resolution"})) ...
                && (i < numel (magics)))
              printOptions.resolution = magics{i+1};
            endif
            if (any (strcmp (magics{i}, {"-w", "--width"})) ...
                && (i < numel (magics)))
              printOptions.width = magics{i+1};
            endif
            if (any (strcmp (magics{i}, {"-h", "--height"})) ...
                && (i < numel (magics)))
              printOptions.height = magics{i+1};
            endif
          endfor
        endif
      endfor

      ## Remember previously opened figures.
      fig_ids = findall (0, "type", "figure");

      ## Create a new figure, if there are existing plots.
      if (! isempty (fig_ids))
        newFig = figure ();
      endif

      stream_output = struct ("name", "stdout", "output_type", "stream");

      output_lines = obj.evalCode (strjoin ( ...
        obj.notebook.cells{cell_index}.source));

      if (! isempty(output_lines))
        stream_output.text = {output_lines};
      endif

      if (isfield (stream_output, "text"))
        obj.notebook.cells{cell_index}.outputs{end + 1} = stream_output;
      endif

      ## If there are existing plots and newFig is empty, delete it.
      if (exist ("newFig") && isempty (get (newFig, "children")))
        delete (newFig);
      endif

      ## Check for newly created figures.
      fig_ids_new = setdiff (findall (0, "type", "figure"), fig_ids);

      if (numel (fig_ids_new) > 0)
        if (exist ("__octave_jupyter_temp__", "dir"))
          ## Delete open figures before raising the error.
          for i = 1:numel (fig_ids_new)
            delete (fig_ids_new(i));
          endfor
          error (["JupyterNotebook: temporary directory ", ...
                  "__octave_jupyter_temp__ exists.  Please remove it ", ...
                  "manually."]);
        endif

        [status, msg, msgid] = mkdir ("__octave_jupyter_temp__");
        if (status == 0)
          ## Delete open figures before raising the error.
          for i = 1 : numel (fig_ids_new)
            delete (fig_ids_new(i));
          endfor
          error (["JupyterNotebook: Cannot create a temporary directory. ", ...
                  msg]);
        endif

        for i = 1:numel (fig_ids_new)
          figure (fig_ids_new(i), "visible", "off");
          obj.embedImage (cell_index, fig_ids_new (i), printOptions);
          delete (fig_ids_new(i));
        endfor

        [status, msg, msgid] = rmdir ("__octave_jupyter_temp__");
        if (status == 0)
          error (["JupyterNotebook: Cannot delete the temporary ", ...
                  "directory. ", msg]);
        endif
      endif

    endfunction


    function runAll (obj)

      ## -*- texinfo -*-
      ## @deftypefn {} {} runAll ()
      ##
      ## Run all cells in the notebook. The results are embedded in the object.
      ##
      ## The evaluation of the code inside the notebook cells is done
      ## in a separate context. This context is loaded before running
      ## the code inside the cell and saved after running it.
      ##
      ## If the code produces figures, those figures are set hidden,
      ## saved in a temporary directory @qcode{__octave_jupyter_temp__},
      ## and removed after being embedded. The temporary directory is
      ## also removed after running the code.
      ##
      ## Your open figures won't be affected by the figures produced by
      ## the code in the notebook.
      ##
      ## See @code{help JupyterNotebook} for examples.
      ##
      ## @end deftypefn

      if (nargin != 1)
        print_usage ();
      endif

      for i = 1 : numel (obj.notebook.cells)
        obj.run(i);
      endfor

    endfunction

  endmethods


  methods (Access = "private")

    function retVal = evalCode (__obj__, __code__)

      ## Evaluate the code string "__code__" using "evalc".
      ## Before the code is evaluated, the previous notebook context is loaded
      ## from "__obj__" and the new context is saved to that struct.

      if (nargin != 2)
        print_usage ();
      endif

      if (isempty (__code__))
        retVal = [];
        return;
      endif

      if (! (ischar (__code__) && isrow (__code__)))
        error ("JupyterNotebook: code must be a string");
      endif

      __obj__.loadContext ();

      retVal = strtrim (evalc (__code__, ["printf (\"error: \"); ", ...
                                          "printf (lasterror.message)"]));

      ## Handle the "ans" variable in the context.
      start_index = rindex (retVal, "ans =") + 6;
      if ((start_index != 6) && (start_index <= length (retVal)))
        end_index = start_index;
        while ((retVal(end_index) != "\n") && (end_index < length (retVal)))
          end_index += 1;
        endwhile
        __obj__.context.ans = retVal(start_index:end_index);
      endif

      __obj__.saveContext ();

    endfunction


    function saveContext (obj, op)

      ## Save the context in private "obj" attribute.

      ## Handle the "ans" variable in the context.
      obj.context = struct ("ans", obj.context.ans);

      forbidden_var_names = {"__code__", "__obj__", "ans"};

      ## Get variable names.
      var_names = {evalin("caller", "whos").name};

      ## Store all variables to context.
      for i = 1:length (var_names)
        if (! any (strcmp (var_names{i}, forbidden_var_names)))
          obj.context.(var_names{i}) = evalin ("caller", var_names{i});
        endif
      endfor

    endfunction


    function loadContext (obj)

      ## Load the context from private "obj" attribute.
      for [val, key] = obj.context
        assignin ("caller", key, val);
      endfor

    endfunction


    function embedImage (obj, cell_index, figHandle, printOptions)

      ## Embed images in the notebook.
      ##
      ## To support a new format:
      ## 1. Create a new function that embeds the new format
      ##    (e.g. embed_svg_image).
      ## 2. Add a new case to the switch-statement below.

      if (isempty (get (figHandle, "children")))
        error_text = {"The figure is empty!"};
        obj.addErrorOutput (cell_index, "The figure is empty!");
        return;
      endif

      ## Check if the resolution is correct
      if (isempty (str2num (printOptions.resolution)))
        obj.addErrorOutput (cell_index, ...
                            "A number is required for resolution, not a string");
        return;
      endif

      ## Check if the width is correct
      if (isempty (str2num (printOptions.width)))
        obj.addErrorOutput (cell_index, ...
                            "A number is required for width, not a string");
        return;
      endif

      ## Check if the height is correct
      if (isempty (str2num (printOptions.height)))
        obj.addErrorOutput (cell_index, ...
                            "A number is required for height, not a string");
        return;
      endif

      switch (lower (printOptions.imageFormat))
        case "png"
          display_output = obj.embed_png_jpg_image (figHandle, ...
                                                    printOptions, "png");
        case "jpg"
          display_output = obj.embed_png_jpg_image (figHandle, ...
                                                    printOptions, "jpg");
        case "svg"
          display_output = obj.embed_svg_image (figHandle, printOptions);
        otherwise
          obj.addErrorOutput (cell_index, ...
                              ["Cannot embed the \'" ...
                               printOptions.imageFormat "\' image format\n"]);
          return;
      endswitch

      obj.notebook.cells{cell_index}.outputs{end + 1} = display_output;

    endfunction


    function dstruct = embed_png_jpg_image (obj, figHandle, printOptions, fmt)

      if (strcmp (fmt, "png"))
        mime = "image/png";
      else
        mime = "image/jpeg";
      endif

      image_path = fullfile ("__octave_jupyter_temp__", ["temp.", fmt]);
      print (figHandle, image_path, ["-d", fmt], ...
             ["-r" printOptions.resolution]);

      dstruct.output_type = "display_data";
      dstruct.metadata.(mime).width  = printOptions.width;
      dstruct.metadata.(mime).height = printOptions.height;
      dstruct.data.("text/plain") = {"<IPython.core.display.Image object>"};
      dstruct.data.(mime) = base64_encode (uint8 (fileread (image_path)));

      delete (image_path);

    endfunction


    function dstruct = embed_svg_image (obj, figHandle, printOptions)

      image_path = fullfile ("__octave_jupyter_temp__", "temp.svg");
      print (figHandle, image_path, "-dsvg", ["-r" printOptions.resolution]);

      dstruct.output_type = "display_data";
      dstruct.metadata = struct ();
      dstruct.data.("text/plain") = {"<IPython.core.display.SVG object>"};
      dstruct.data.("image/svg+xml") = strsplit (fileread (image_path), "\n");

      ## FIXME: The following is a workaround until we can properly print
      ##        SVG images in the right width and height.
      ## Detect the <svg> tag. it is either the first or the second item
      if (strncmpi (dstruct.data.("image/svg+xml"){1}, "<svg", 4))
        i = 1;
      else
        i = 2;
      endif

      ## Embed the width and height in the image itself
      svg_tag = dstruct.data.("image/svg+xml"){i};
      svg_tag = regexprep (svg_tag, "width=\"(.*?)\"",
                           ["width=\"" printOptions.width "px\""]);
      svg_tag = regexprep (svg_tag, "height=\"(.*?)\"",
                           ["height=\"" printOptions.height "px\""]);
      dstruct.data.("image/svg+xml"){i} = svg_tag;

      delete (image_path);

    endfunction


    function addErrorOutput (obj, cell_index, error_msg)

      stream_output.name        = "stderr";
      stream_output.output_type = "stream";
      stream_output.text        = {error_msg};
      obj.notebook.cells{cell_index}.outputs{end + 1} = stream_output;

    endfunction

  endmethods

endclassdef

## Test running a single cell
%!test
%! n = JupyterNotebook ("../examples/octave_kernel.ipynb");
%! 
%! ## Test embedding images
%! n.run (2);
%! assert (n.notebook.cells{2}.outputs{1}.output_type, "display_data")
%! assert (isfield (n.notebook.cells{2}.outputs{1}.data, "image/png"));
%! assert (getfield (n.notebook.cells{2}.outputs{1}.data, "text/plain"),
%!         {"<IPython.core.display.Image object>"});
%! 
%! ## Test running non-code cells
%! markdown_cell = n.notebook.cells{1};
%! n.run (1);
%! assert (markdown_cell, n.notebook.cells{1});

## Test running all cells
%!test
%! n = JupyterNotebook ("../examples/octave_kernel.ipynb");
%! n.runAll ();
%!
%! ## Test embedding images
%! assert (n.notebook.cells{3}.outputs{1}.output_type, "display_data")
%! assert (isfield (n.notebook.cells{3}.outputs{1}.data, "image/png"));
%! assert (getfield (n.notebook.cells{3}.outputs{1}.data, "text/plain"),
%!         {"<IPython.core.display.Image object>"});
%! 
%! ## Test running non-code cells
%! markdown_cell = n.notebook.cells{1};
%! assert (markdown_cell, n.notebook.cells{1});
%! 
%! ## Test embedding textual output
%! assert (n.notebook.cells{6}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{6}.outputs{1}.name, "stdout");
%! assert (n.notebook.cells{6}.outputs{1}.text, {"4   5   6"});

## Test loading and storing the context
%!test
%! n = JupyterNotebook ("../examples/octave_kernel.ipynb");
%! 
%! ## Run a cell that uses variables from the previous cell
%! n.run (5);
%! assert (n.notebook.cells{5}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{5}.outputs{1}.name, "stdout");
%! assert (n.notebook.cells{5}.outputs{1}.text, 
%!         {"ans = \nerror: 'a' undefined near line 1 column 2"});
%! 
%! ## Run the previous cell to store the used variables in the context
%! n.run (4);
%! 
%! ## Re-run the cell
%! n.run (5);
%! assert (n.notebook.cells{5}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{5}.outputs{1}.name, "stdout");
%! assert (n.notebook.cells{5}.outputs{1}.text, 
%!         {"ans =  8\na =\n\n   1   2   3"});

## Test plot magic
%!test
%! n = JupyterNotebook ("../examples/plot_magic_and_errors.ipynb");
%! 
%! ## PNG format
%! n.run (1);
%! assert (n.notebook.cells{1}.outputs{1}.output_type, "display_data")
%! assert (isfield (n.notebook.cells{1}.outputs{1}.data, "image/png"));
%! assert (getfield (n.notebook.cells{1}.outputs{1}.data, "text/plain"),
%!         {"<IPython.core.display.Image object>"});
%!
%! ## SVG format
%! n.run (2);
%! assert (n.notebook.cells{2}.outputs{1}.output_type, "display_data")
%! assert (isfield (n.notebook.cells{2}.outputs{1}.data, "image/svg+xml"));
%! assert (getfield (n.notebook.cells{2}.outputs{1}.data, "text/plain"),
%!         {"<IPython.core.display.SVG object>"});
%!
%! ## JPG format
%! n.run (3);
%! assert (n.notebook.cells{3}.outputs{1}.output_type, "display_data")
%! assert (isfield (n.notebook.cells{3}.outputs{1}.data, "image/jpeg"));
%! assert (getfield (n.notebook.cells{3}.outputs{1}.data, "text/plain"),
%!         {"<IPython.core.display.Image object>"});

## Test errors
%!test
%! n = JupyterNotebook ("../examples/plot_magic_and_errors.ipynb");
%! 
%! ## Wrong resolution
%! n.run (4);
%! assert (n.notebook.cells{4}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{4}.outputs{1}.name, "stderr");
%! assert (n.notebook.cells{4}.outputs{1}.text, 
%!         {"A number is required for resolution, not a string"});
%!
%! ## Wrong width
%! n.run (5);
%! assert (n.notebook.cells{5}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{5}.outputs{1}.name, "stderr");
%! assert (n.notebook.cells{5}.outputs{1}.text, 
%!         {"A number is required for width, not a string"});
%!
%! ## Wrong height
%! n.run (6);
%! assert (n.notebook.cells{6}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{6}.outputs{1}.name, "stderr");
%! assert (n.notebook.cells{6}.outputs{1}.text, 
%!         {"A number is required for height, not a string"});
%!
%! ## Empty figure
%! n.run (7);
%! assert (n.notebook.cells{7}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{7}.outputs{1}.name, "stderr");
%! assert (n.notebook.cells{7}.outputs{1}.text, 
%!         {"The figure is empty!"});
%!
%! ## Wrong format
%! n.run (8);
%! assert (n.notebook.cells{8}.outputs{1}.output_type, "stream")
%! assert (n.notebook.cells{8}.outputs{1}.name, "stderr");
%! assert (n.notebook.cells{8}.outputs{1}.text, 
%!         {"Cannot embed the 'pdf' image format\n"});
