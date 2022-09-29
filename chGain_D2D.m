function g = chGain_D2D(bandwidth, x_1, y_1, z_1, x_2, y_2, z_2)
    global shadowing;
    global BS_POSITION;

    d = sqrt((x_1-x_2)^2 + (y_1-y_2)^2 + (z_1-z_2)^2);
    pathloss =46.8 + 16.9*log10(d) + 20*log10(2/5) + 12*shadowing;
                % (44.9-6.55*log10(BS_POSITION.z))*log10(d)+5.83*log10(BS_POSITION.z)+15.38+23*log10(bandwidth/1e9/2) + 4*shadowing);
    % fprintf('pathloss = %.5f, dis=%.2f, free_pl=%.5f, B1_pl=%.5f\n', pathloss, d, 46.4 + 20*log10(d) + 20*log10(bw_ghz), (44.9-6.55*log10(BS_POSITION.z))*log10(d)+5.83*log10(BS_POSITION.z)+15.38+23*log10(bandwidth/1e9/2))
    g = 10^(-pathloss/10);
end