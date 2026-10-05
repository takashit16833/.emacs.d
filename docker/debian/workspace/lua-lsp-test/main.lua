local function greet(name)
  return ("Hello, %s!"):format(name)
end

local message = greet("Emacs")

print(message)

-- LSP確認用:
-- - greet の呼び出し元から定義ジャンプできることを確認する。
-- - message などを入力途中まで削って補完候補が出ることを確認する。
-- - 次の行のコメントを外し、未定義変数の診断が出ることを確認する。
-- print(undefined_value)
