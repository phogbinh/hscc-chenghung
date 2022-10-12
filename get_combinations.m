function combinations = get_combinations(RUEs_num, DUEs_num)
  values = 0:RUEs_num;
  combinations = values(dec2base(0:(RUEs_num + 1)^DUEs_num - 1, RUEs_num + 1) - '0' + 1);
end
