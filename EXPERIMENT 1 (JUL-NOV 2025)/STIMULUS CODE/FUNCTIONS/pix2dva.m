function dva = pix2dva(pixel,eyeScreenDistance,windowRect,screenHeight)

% pixel = tand(dva) * eyeScreenDistence *  rect(4)/screenHeight;
dva = atand(pixel * screenHeight/(eyeScreenDistance *  windowRect(4))); 