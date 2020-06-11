TESTS_NIX = 						\
  tests.nix

TESTS_BATS =						\
  tests.bats

check:
	bats $(TESTS_BATS)

check-system:
	nix-build --no-out-link $(TESTS_NIX)
