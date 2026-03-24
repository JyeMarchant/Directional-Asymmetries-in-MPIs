function isWithin = isWithinFixationWindow(x, y, centerX, centerY, radius)
    % Check if gaze coordinates (x,y) are within the fixation window
    %
    % Parameters:
    %   x, y - gaze coordinates in pixels
    %   centerX, centerY - center of fixation window in pixels
    %   radius - radius of fixation window in pixels
    %
    % Returns:
    %   isWithin - true if gaze is within window, false otherwise
    
    if isnan(x) || isnan(y)
        isWithin = false;
    else
        distance = sqrt((x - centerX)^2 + (y - centerY)^2);
        isWithin = distance <= radius;
    end
end