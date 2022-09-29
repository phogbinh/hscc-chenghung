function sinr = SINR(resource, x_1, y_1, z_1, x_2, y_2, z_2)
% calculate the SINR value on the destined resource, where
% the transmitter is at (x_1, y_1, z_1)
% the receiver is at (x_2, y_2, z_2)
% noise spectral density(N0) = -173dbm/Hz
% interference from adjacent cells(I0) = -174dbm/Hz
% pathloss model = 127.1 + 37.6log10(d), d is in meters
    global shadowing;
    N0 = -174.0;
    I0 = -140.0;
    
    d = sqrt((x_1-x_2)^2 + (y_1-y_2)^2 + (z_1-z_2)^2);
    pathloss = 128.1 + 37.6*log10(d/1000.0)+ 10*shadowing;
    N0 = 10^(N0/10);
    I0 = 10^(I0/10);
 
    sinr = (resource.tx_power / 10^(pathloss/10)) / (resource.bandwidth*(I0+N0));
    % fprintf('p:%e, pl: %e, noise: %e, sinr: %e\n', resource.tx_power, pathloss, resource.bandwidth*(I0+N0), sinr);

end