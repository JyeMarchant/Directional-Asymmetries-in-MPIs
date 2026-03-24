function result = iif(condition, trueValue, falseValue)
    % Inline if function - returns trueValue if condition is true, otherwise falseValue
    % Useful for concise conditional assignments
    %
    % Example: response = iif(correct, 'Correct!', 'Incorrect');
    
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end