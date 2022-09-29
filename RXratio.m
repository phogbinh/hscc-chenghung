function [ratio] = RXratio(tx_power, DUE, RUE, resource)
% receiving power = tx power * RXratio
    ratio = 0;
    tx_energy = 0;
    rx_energy = 0;
    pos = DUE.getPosition();
    rpos = RUE.getPosition();
    if tx_power == 0
        return;
    end

    if tx_power <= 10^0.02
        tx_energy = 0.78 * 10*log10(tx_power) + 23.6;
    elseif tx_power > 10^0.02 & tx_power <= 10^1.14
        tx_energy = 17 * 10*log10(tx_power) + 45.4;
    elseif tx_power > 10^1.14
        tx_energy = 5.9 * (10*log10(tx_power))^2 - 118 * 10*log10(tx_power) + 1195;
    end

    if tx_power <= 10^-5.25
        rx_energy = -0.04 * 10*log10(tx_power*chGain_D2D(resource.bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z)) + 24.8;
    else
        rx_energy = -0.11 * 10*log10(tx_power*chGain_D2D(resource.bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z)) + 7.86;
    end
    
    sinr = SINR_D2D(tx_power, resource.bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
    rate = resource.bandwidth * log2(1 + sinr) / 1e6;
    tx_energy = tx_energy + 0.62;
    rx_energy = rx_energy + (0.97 * rate + 8.16);

    % fprintf('rx_power = %.2f, tx_power = %.2f\n', rx_energy, tx_energy);
    ratio = rx_energy / tx_energy;
end