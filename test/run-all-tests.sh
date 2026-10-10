#!/bin/sh
# Run unit and integration tests separately, from the project root.
# Keep going after a failure so "All tests" reports every test suite.

status=0

printf '\n=== Unit tests ===\n'
emacs -Q --batch -L elisp -L test \
  --eval "(progn (mapc #'load-file (directory-files \"test\" t \"-test[.]el$\")) (ert-run-tests-batch-and-exit))" \
  || status=1

for test_file in test/*-integration.el; do
  [ -f "$test_file" ] || continue
  printf '\n=== Integration: %s ===\n' "$test_file"
  emacs -Q --batch -L elisp \
    --eval '(package-initialize)' \
    -l "$test_file" \
    -f ert-run-tests-batch-and-exit \
    || status=1
done

exit "$status"
