## Copyright (C) 2020 The Octave Project Developers
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
  ## @deftypefn  {} {@var{notebook} =} JupyterNotebook ()
  ##
  ## Run and fill Jupyter Notebooks within GNU Octave. 
  
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

      obj.notebook = jsondecode (fileread (notebookFileName));

      # Validate the notebook's format according to nbformat: 4.0 
      if (! (isfield (obj.notebook, "metadata") && 
             isfield (obj.notebook, "nbformat") &&
             isfield (obj.notebook, "nbformat_minor") && 
             isfield (obj.notebook, "cells")))
        error ("JupyterNotebook: not valid format for Jupyter notebooks");
      endif

      # Issue a warning if the format is lower than 4.0
      if (obj.notebook.nbformat < 4)
        warning ("JupyterNotebook: nbformat versions lower than 4.0 are not supported")
      endif

      # Handle the case if there is only one cell.
      # Make "obj.notebook.cells" a cell of structs to match the format 
      if (numel (obj.notebook.cells) == 1)
        obj.notebook.cells = {obj.notebook.cells};
      endif

      # Handle the case if the cells have the same keys
      # Make "obj.notebook.cells" a cell of structs instead of struct array
      # to unify the indexing method
      if (isstruct (obj.notebook.cells))
        obj.notebook.cells = num2cell (obj.notebook.cells);
      endif

      for i = 1 : numel (obj.notebook.cells)
        if ( ! isfield (obj.notebook.cells{i}, "source"))
          error ("JupyterNotebook: cells must contain a \"source\" field");
        endif
        if ( ! isfield (obj.notebook.cells{i}, "cell_type"))
          error ("JupyterNotebook: cells must contain a \"cell_type\" field");
        endif
        # Handle when null json values are decoded into empty arrays 
        if (isfield (obj.notebook.cells{i}, "execution_count") &&
            numel (obj.notebook.cells{i}.execution_count) == 0)
          obj.notebook.cells{i}.execution_count = 1;    
        endif
      endfor
    endfunction

    function generateOctaveScript (obj, scriptFileName)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (scriptFileName) && isrow (scriptFileName)))
        error ("JupyterNotebook: scriptFileName must be a string");
      endif

      fhandle = fopen(scriptFileName, "w");

      for i = 1:numel(obj.notebook.cells)
        if (strcmp(obj.notebook.cells{i}.cell_type, "markdown"))
          fputs (fhandle, "\n#{\n");
        endif

        for k = 1:numel(obj.notebook.cells{i}.source)
          fputs (fhandle, obj.notebook.cells{i}.source{k});
        endfor

        if (strcmp(obj.notebook.cells{i}.cell_type, "markdown"))
          fputs (fhandle, "\n#}\n");
        endif
        fputs (fhandle, "\n");
      endfor
      fclose (fhandle);
    endfunction

    function generateNotebook (obj, notebookFileName)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (ischar (notebookFileName) && isrow (notebookFileName)))
        error ("JupyterNotebook: notebookFileName must be a string");
      endif

      fhandle = fopen(notebookFileName, "w");

      fputs (fhandle, jsonencode (obj.notebook, "ConvertInfAndNaN", false,
                                  "PrettyPrint", true));

      fclose (fhandle);
    endfunction

    function run (obj, cell_index)
      if (nargin != 2)
        print_usage ();
      endif

      if (! (isscalar (cell_index) && ! islogical (cell_index) &&
          mod (cell_index, 1) == 0 && cell_index > 0))
        error ("JupyterNotebook: cell_index must be a scalar positive integer");
      endif

      if (cell_index > length (obj.notebook.cells))
        error ("JupyterNotebook: cell_index is out of bound");
      endif

      if (! strcmp (obj.notebook.cells{cell_index}.cell_type, "code"))
        return;
      endif

      # Remove previous outputs
      obj.notebook.cells{cell_index}.outputs = {};

      if (isempty (obj.notebook.cells{cell_index}.source))
        return;
      endif

      # Default values for printOptions
      printOptions.imageFormat = "png";
      printOptions.resolution = "150";
      # The default width and height in Jupyter notebook
      printOptions.width = "640";
      printOptions.height = "480";

      # Parse plot magic
      for j = 1 : numel (obj.notebook.cells{cell_index}.source)
        if (strncmpi (obj.notebook.cells{cell_index}.source{j}, "%plot", 5))
          magics = strsplit (strtrim (obj.notebook.cells{cell_index}.source{j}));
          for i = 1 : numel (magics)
            if ((strcmp (magics{i}, "-f") || (strcmp (magics{i}, "--format"))) &&
                i < numel (magics))
              printOptions.imageFormat = magics{i+1};
            endif 
            if ((strcmp (magics{i}, "-r") || (strcmp (magics{i}, "--resolution"))) &&
                i < numel (magics))
              printOptions.resolution = magics{i+1};
            endif
            if ((strcmp (magics{i}, "-w") || (strcmp (magics{i}, "--width"))) &&
                i < numel (magics))
              printOptions.width = magics{i+1};
            endif
            if ((strcmp (magics{i}, "-h") || (strcmp (magics{i}, "--height"))) &&
                i < numel (magics))
              printOptions.height = magics{i+1};
            endif
          endfor
        endif
      endfor

      # Remember previously opened figures
      fig_ids = findall (0, "type", "figure");

      # Create a new figure, if there are existing plots
      if (! isempty (fig_ids))
        newFig = figure ();
      endif

      stream_output = struct ("name", "stdout", "output_type", "stream");

      output_lines = obj.evalCode (strjoin (obj.notebook.cells{cell_index}.source));

      if (! isempty(output_lines))
          stream_output.text = {output_lines};
      endif

      if (isfield (stream_output, "text"))
        obj.notebook.cells{cell_index}.outputs{end + 1} = stream_output;
      endif

      # If there are existing plots and newFig is empty, delete it
      if (exist ("newFig") && isempty (get (newFig, "children")))
        delete (newFig);
      endif

      # Check for newly created figures
      fig_ids_new = setdiff (findall (0, "type", "figure"), fig_ids);

      for i = 1 : numel (fig_ids_new)
        figure (fig_ids_new (i), "visible", "off"); 
        obj.embedImage (cell_index, fig_ids_new (i), printOptions);
        delete (fig_ids_new(i));
      endfor
    endfunction

    function runAll (obj)
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

      __obj__.evalContext ("load");

      retVal = strtrim (evalc (__code__, "printf (\"error: \"); printf (lasterror.message)"));

      # Handle the "ans" var in the context
      start_index = rindex (retVal, "ans =") + 6;
      if (start_index != 6 && start_index <= length (retVal))
        end_index = start_index;
        while (retVal(end_index) != "\n" && end_index < length (retVal))
          end_index += 1;
        endwhile
        __obj__.context.ans = retVal(start_index:end_index);
      endif

      __obj__.evalContext ("save");

    endfunction

    function evalContext (obj, op)
      if (strcmp (op, "save"))
        # Handle the ans var in the context
        obj.context = struct("ans", obj.context.ans);
        
        forbidden_var_names = {"__code__", "__obj__", "ans"};

        ## Get variable names
        var_names = {evalin("caller", "whos").name};

        ## Store all variables to context
        for i = 1:length (var_names)
          if (! any (strcmp (var_names{i}, forbidden_var_names)))
            obj.context.(var_names{i}) = evalin ("caller", var_names{i});
          endif
        endfor
      elseif (strcmp (op, "load"))
        for [val, key] = obj.context
          assignin ("caller", key, val);
        endfor
      endif
    endfunction

    function embedImage (obj, cell_index, figHandle, printOptions)
      if (isempty (get (figHandle, "children")))
        error_text = {"The figure is empty!"};
        obj.addErrorOutput (cell_index, "The figure is empty!");
        return;
      endif

      # Check if the resolution is correct
      if (isempty (str2num (printOptions.resolution)))
        obj.addErrorOutput (cell_index, 
                            "A number is required for resolution, not a string");
        return;
      endif

      # Check if the width is correct
      if (isempty (str2num (printOptions.width)))
        obj.addErrorOutput (cell_index, 
                            "A number is required for width, not a string");
        return;
      endif 

      # Check if the height is correct
      if (isempty (str2num (printOptions.height)))
        obj.addErrorOutput (cell_index, 
                            "A number is required for height, not a string");
        return;
      endif 
      
      if (strcmpi (printOptions.imageFormat, "png"))
        embedPNGImage (obj, cell_index, figHandle, printOptions);
      elseif (strcmpi (printOptions.imageFormat, "svg"))
        embedSVGImage (obj, cell_index, figHandle, printOptions);
      elseif (strcmpi (printOptions.imageFormat, "jpg"))
        embedJPGImage (obj, cell_index, figHandle, printOptions);
      else
        obj.addErrorOutput (cell_index, 
                            ["Cannot embed the \'" ...
                             printOptions.imageFormat "\' image format\n"]);
      endif
    endfunction

    function embedPNGImage (obj, cell_index, figHandle, printOptions)
      print (figHandle, "temp.png", "-dpng", ["-r" printOptions.resolution]);
      metadata = struct ("image/png", struct ("width", printOptions.width,
                                              "height", printOptions.height));
      encodedImage = base64_encode (uint8 (fileread ("temp.png")));
      display_output = struct ("output_type", "display_data", "metadata", metadata,
                              "data", struct ("text/plain", 
                                              {"<IPython.core.display.Image object>"},
                                              "image/png", encodedImage));
      obj.notebook.cells{cell_index}.outputs{end + 1} = display_output;
      delete ("temp.png");
    endfunction

    function embedSVGImage (obj, cell_index, figHandle, printOptions)
      print (figHandle, "temp.svg", "-dsvg", ["-r" printOptions.resolution]);
      metadata = struct ("image/svg+xml", struct ("width", printOptions.width,
                                                  "height", printOptions.height));
      display_output = struct ("output_type", "display_data", "metadata", metadata,
                                "data", struct ());
      # Use dot notation to avoid making a struct array
      display_output.data.("image/svg+xml") = strsplit (fileread ("temp.svg"), "\n");
      display_output.data.("text/plain") = {"<IPython.core.display.SVG object>"};                                        
      obj.notebook.cells{cell_index}.outputs{end + 1} = display_output;
      delete ("temp.svg");
    endfunction

    function embedJPGImage (obj, cell_index, figHandle, printOptions)
      print (figHandle, "temp.jpg", "-djpg", ["-r" printOptions.resolution]);
      metadata = struct ("image/jpeg", struct ("width", printOptions.width,
                                               "height", printOptions.height));
      encodedImage = base64_encode (uint8 (fileread ("temp.jpg")));
      display_output = struct ("output_type", "display_data", "metadata", metadata,
                              "data", struct ("text/plain", 
                                              {"<IPython.core.display.Image object>"},
                                              "image/jpeg", encodedImage));
      obj.notebook.cells{cell_index}.outputs{end + 1} = display_output;
      delete ("temp.jpg");
    endfunction

    function addErrorOutput (obj, cell_index, error_msg)
      stream_output = struct ("name", "stderr", "output_type", "stream");
      # Use dot notation to avoid making a struct array
      stream_output.text = {error_msg};
      obj.notebook.cells{cell_index}.outputs{end + 1} = stream_output;
    endfunction
  endmethods
endclassdef
