function g = chGain(x_1, y_1, z_1, x_2, y_2, z_2)
    global shadowing;
    d = sqrt((x_1-x_2)^2 + (y_1-y_2)^2 + (z_1-z_2)^2);
    pathloss = 128.1 + 37.6*log10(d/1000.0) + 10*shadowing;

    g = 10^(-pathloss/10);
end