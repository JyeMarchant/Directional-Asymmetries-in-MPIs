function pixel = dva2pix(dva,eyeScreenDistance,windowRect,screenHeight)

pixel = round(tand(dva) * eyeScreenDistance *  windowRect(4)/screenHeight);