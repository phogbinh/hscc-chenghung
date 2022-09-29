function sinr = SINR_D2D(power, bandwidth, x_1, y_1, z_1, x_2, y_2, z_2)
    N0 = -174.0;
    I0 = -140.0;
    global shadowing;
    global BS_POSITION;

    d = sqrt((x_1-x_2)^2 + (y_1-y_2)^2 + (z_1-z_2)^2);
    pathloss = 46.8 + 16.9*log10(d) + 20*log10(2/5) + 12*shadowing;
                % (44.9-6.55*log10(BS_POSITION.z))*log10(d)+5.83*log10(BS_POSITION.z)+15.38+23*log10(bandwidth/1e9/2) + 12*shadowing);
    N0 = 10^(N0/10);
    I0 = 10^(I0/10);

    sinr = (power / 10^(pathloss/10)) / (bandwidth*(I0+N0));
end