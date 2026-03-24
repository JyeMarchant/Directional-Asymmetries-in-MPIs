function staircase = update_by_response_switch(staircase, currentResponse, lastResponse)
% This function is designed to update the staircase depending on the
% previous response for that particular condition (There are 6
% staircases) Step size reduces by 1.5x after each reversal. 



    % Store previous direction
    previousDirection = staircase.direction;
    
    % Check for response switch (reversal)
    if currentResponse ~= lastResponse
        % Response switched - this is a reversal
        staircase.reversals = staircase.reversals + 1;
        
        % Reduce step size BEFORE updating level 
        if staircase.reversals >= 3 && mod(staircase.reversals, 2) == 0 && staircase.step > staircase.minimumStepSize
            staircase.step = max(staircase.step / 1.5, staircase.minimumStepSize);
        end
        
        % Change direction based on current response (NOW uses potentially reduced step size)
        if currentResponse == 2 % F key: Move probe more peripheral
            staircase.stimuluslevel = staircase.stimuluslevel + staircase.step;
            staircase.direction = 1; % Moving toward periphery
        elseif currentResponse == 1 % P key: Move probe more foveal
            staircase.stimuluslevel = staircase.stimuluslevel - staircase.step;
            staircase.direction = -1; % Moving toward fovea
        end
        
    else
        % Same response as last time - continue in same direction
        if currentResponse == 2 % F key: Move probe more peripheral
            staircase.stimuluslevel = staircase.stimuluslevel + staircase.step;
            staircase.direction = 1; % Moving toward periphery
        elseif currentResponse == 1 % P key: Move probe more foveal
            staircase.stimuluslevel = staircase.stimuluslevel - staircase.step;
            staircase.direction = -1; % Moving toward fovea
        end
    end
    
    % Log progression
    staircase.progression(end+1) = staircase.stimuluslevel;
    

end