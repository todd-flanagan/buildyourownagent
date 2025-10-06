function buildyourownagent()
% Initialize the agent's environment and settings
    runAgent()


    function codeBlock = extractMarkdownBlock(response, blockType)
        if nargin < 2
            blockType = "json";
        end

        if ~contains(response, '```')
            codeBlock = response;
            return;
        end

        parts = strsplit(response, '```');
        codeBlock = strtrim(parts{2});

        if startsWith(codeBlock, blockType)
            codeBlock = strtrim(extractAfter(codeBlock, blockType));
        end
    end

    % Call LLM to get a response
    function responseContent = generateResponse(messages)
        % In MATLAB, we would need to use a HTTP request to call the OpenAI API
        % This is a placeholder for the actual API call
        url = 'https://api.openai.com/v1/chat/completions';
        headers = {'Content-Type', 'application/json', 'Authorization', ['Bearer ', getSecret('OPENAI_API_KEY')]};

        data = struct('model', 'openai/gpt-4o', ...
            'messages', messages, ...
            'max_tokens', 1024);

        options = weboptions('HeaderFields', headers, 'MediaType', 'application/json');
        response = webwrite(url, jsonencode(data), options);

        % Parse the response
        responseStruct = jsondecode(response);
        responseContent = strtrim(responseStruct.choices(1).message.content);
    end

    % Parse the LLM response into a structured action dictionary
    function actionStruct = parseAction(response)
        try
            response = extractMarkdownBlock(response, "action");
            actionStruct = jsondecode(response);

            if ~isfield(actionStruct, 'tool_name') || ~isfield(actionStruct, 'args')
                actionStruct = struct('tool_name', 'error', ...
                    'args', struct('message', 'You must respond with a JSON tool invocation.'));
            end
        catch
            actionStruct = struct('tool_name', 'error', ...
                'args', struct('message', 'Invalid JSON response. You must respond with a JSON tool invocation.'));
        end
    end

    % List files in the specified directory
    function fileList = listSrFiles(folder)
        fileList = dir(folder);
        fileList = {fileList(~[fileList.isdir]).name};
    end

% Create a new empty file
    function createFile(fileName)
        fileID = fopen(fileName, 'w');
        fclose(fileID);
    end

    % Read a file contents
    function content = readFile(fileName, folder)
        if nargin < 2
            folder = '.';
        end

        fullPath = fullfile(folder, fileName);

        try
            fileID = fopen(fullPath, 'r');
            content = fscanf(fileID, '%c');
            fclose(fileID);
        catch e
            if contains(e.message, 'No such file or directory')
                content = ['Error: ', fileName, ' not found.'];
            else
                content = ['Error: ', e.message];
            end
        end
    end

% Write results to a file
    function writeResults(fileName, results)
        fileID = fopen(fileName, 'a');
        fprintf(fileID, '%s\n', results);
        fclose(fileID);
    end

    % Terminate the agent loop
    function terminateMsg = terminate(message)
        terminateMsg = ['Termination message: ', message];
        disp(terminateMsg);
    end

    % Main script
    function runAgent()
        % Define tool functions as a containers.Map
        toolFunctions = dictionary();
        toolFunctions('list_sr_files') = @listSrFiles;
        toolFunctions('read_file') = @readFile;
        toolFunctions('write_results') = @writeResults;
        toolFunctions('create_file') = @createFile;
        toolFunctions('terminate') = @terminate;

        % Define tools as a cell array of structs
        tools = {
            struct('type', 'function', ...
            'name', 'list_sr_files', ...
            'description', 'Returns a list of service request files.', ...
            'parameters', struct('type', 'object', ...
            'properties', struct('folder', struct('type', 'string'))), ...
            'required', {'folder'}), ...
            struct('type', 'function', ...
            'name', 'read_file', ...
            'description', 'Reads the content of a specified file in the directory.', ...
            'parameters', struct('type', 'object', ...
            'properties', struct('file_name', struct('type', 'string'), ...
            'folder', struct('type', 'string'))), ...
            'required', {'file_name'}), ...
            struct('type', 'function', ...
            'name', 'create_file', ...
            'description', 'Creates a new file of the given name.', ...
            'parameters', struct('type', 'object', ...
            'properties', struct('file_name', struct('type', 'string'))), ...
            'required', {'file_name'}), ...
            struct('type', 'function', ...
            'name', 'write_results', ...
            'description', 'writes a string to a file', ...
            'parameters', struct('type', 'object', ...
            'properties', struct('file_name', struct('type', 'string'))), ...
            'required', {'file_name'}), ...
            struct('type', 'function', ...
            'name', 'terminate', ...
            'description', 'Terminates the conversation. No further actions or interactions are possible after this. Prints the provided message for the user.', ...
            'parameters', struct('type', 'object', ...
            'properties', struct('message', struct('type', 'string'))), ...
            'required', {'message'})
            };

        %Define system instructions (Agent Rules)
        agentRules = {struct('role', 'system', ...
             'content', ['You are an AI agent that can perform tasks by using available tools.\n\n', ...
             'create a new, blank file named out.txt\n', ...
             'retreive the list of service request files from the folder buildyourownagent/srs.  read each file.  If the file is not in english, translate it to english.\n', ...
             'for each file, suggest a list of 2-3 tags to categorize the request, an assessment of where it is in the workflow,\n', ...
             'and an issue type.  Then append the list of tags to out.txt in the form of <srfilebane> : <deploment step> : <issue type> : <tag1>, <tag2>...\n', ...
             'where deployment step represents the step in the deployment process the customer experienced the issue.\n', ...
             'the valid deployment steps are in the file buildyourownagent/agentdata/deploymentsteps.txt\n', ...
             'Valid issue types are: request, howto, inquiry, issue.\n', ...
             'The valid tags are in tags.txt in the buildyourownagent/agentdata folder\n\n', ...
             'When you are done, terminate the conversation by using the "terminate" tool and I will provide the results to the user.'])};


        % agentRules = {struct('role', 'system', ...
        %      'content', 'say hello')};
 
        % Initialize agent parameters

        iterations = 0;
        maxIterations = 20;

        userTask = 'process the srs';

        memory = {struct('role', 'user', 'content', userTask)};

        % The Agent Loop
        while iterations < maxIterations
            % 1. Construct prompt: Combine agent rules with memory
            disp(memory);
%            input = [agentRules, memory];
            input = agentRules;
            % 2. Generate response from LLM
            disp('Agent thinking...');

            % In a real implementation, we would call the OpenAI API here
            % For this example, we'll simulate the API call
            url = 'https://api.openai.com/v1/responses';
            o = weboptions;
            o.HeaderFields = ["Authorization", "Bearer " + getSecret('OPENAI_API_KEY')];
            o.ContentType = 'text';
            o.MediaType = 'application/json';
            data.model = 'gpt-4o';
            data.input = input;
            data.tools = tools;
            data.max_output_tokens = 1024;

            % This is a placeholder for the actual API call
            d = jsonencode(data);
            response = webwrite(url, d, o);
            responseStruct = extractMarkdownBlock(response);

            % Simulate a response for this example
            disp('Agent response: ' + responseStruct);

            % Simulate tool calls
            % In a real implementation, we would parse the actual response
            hasTool = true; % Simulated

            if hasTool
                % Simulate tool call
                toolName = 'list_sr_files'; % Example
                toolArgs = struct('folder', 'buildyourownagent/srs'); % Example
                action = struct('tool_name', toolName, 'args', toolArgs);

                if strcmp(toolName, 'terminate')
                    disp(terminate(action.args.message));
                    break;
                elseif isKey(toolFunctions, toolName)
                    try
                        % Call the function dynamically
                        if strcmp(toolName, 'list_sr_files')
                            %result = struct('result', {toolFunctions(toolName)(toolArgs.folder)});
                        elseif strcmp(toolName, 'read_file')
                            if isfield(toolArgs, 'folder')
                                %result = struct('result', toolFunctions(toolName)(toolArgs.file_name, toolArgs.folder));
                            else
                                %result = struct('result', toolFunctions(toolName)(toolArgs.file_name));
                            end
                        elseif strcmp(toolName, 'create_file')
                            %toolFunctions(toolName)(toolArgs.file_name);
                            result = struct('result', 'File created');
                        elseif strcmp(toolName, 'write_results')
                            %toolFunctions(toolName)(toolArgs.file_name, toolArgs.results);
                            result = struct('result', 'Results written');
                        else
                            %result = struct('result', toolFunctions(toolName)(toolArgs.message));
                        end
                    catch e
                        result = struct('error', ['Error executing ', toolName, ': ', e.message]);
                    end
                else
                    result = struct('error', ['Unknown tool: ', toolName]);
                end

                fprintf('Executing: %s with args %s\n', toolName, jsonencode(toolArgs));
                disp(['Action result: ', jsonencode(result)]);

                % 5. Update memory with response and results
                memory = [memory, {struct('role', 'assistant', 'content', jsonencode(action))}, ...
                    {struct('role', 'user', 'content', jsonencode(result))}];
            else
                % Handle regular message response
                result = 'Simulated message content';
                disp(['Action result: ', result]);
            end

            iterations = iterations + 1;
        end
    end

end