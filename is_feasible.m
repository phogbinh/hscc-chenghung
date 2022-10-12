function result = is_feasible(combination, RUEs_num)
  global MAX_LEN;
  for rue_mli = 1:RUEs_num
    relay_DUEs_num = 0;
    for due_mli = 1:numel(combination)
      if combination(due_mli) == rue_mli
        relay_DUEs_num = relay_DUEs_num + 1;
      end
    end
    if relay_DUEs_num > MAX_LEN
      result = false;
      return;
    end
  end
  result = true;
end
