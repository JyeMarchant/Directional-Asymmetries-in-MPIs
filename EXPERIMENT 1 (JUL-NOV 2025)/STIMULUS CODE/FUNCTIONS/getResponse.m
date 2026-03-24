function response = getResponse(allowedKeys, escapeAllowed)
    % Get keyboard response from user with multi-keyboard support
    %
    % Parameters:
    %   allowedKeys - cell array of allowed key names (default: {'i', 'o'})
    %   escapeAllowed - whether ESCAPE key exits (default: true)
    %
    % Returns:
    %   response - the key pressed as a string
    %
    % Example: response = getResponse({'i', 'o'}, true);
    
    if nargin < 1
        allowedKeys = {'i', 'o'};
    end
    if nargin < 2
        escapeAllowed = true;
    end
    
    response = '';
    respToBeMade = true;
    
    % Get all keyboard indices for multi-keyboard support
    keyboardIndices = GetKeyboardIndices();
    
    while respToBeMade
        for keyIdx = 1:length(keyboardIndices)
            [keyIsDown, ~, keyCode] = KbCheck(keyboardIndices(keyIdx));
            if keyIsDown
                if escapeAllowed && keyCode(KbName('ESCAPE'))
                    error('Experiment terminated by user');
                end
                
                % Check each allowed key
                for i = 1:length(allowedKeys)
                    if keyCode(KbName(allowedKeys{i}))
                        response = allowedKeys{i};
                        respToBeMade = false;
                        break;
                    end
                end
                
                if ~respToBeMade
                    break;
                end
            end
        end
        WaitSecs(0.001);
    end
    
    % Wait for key release
    KbReleaseWait();
end