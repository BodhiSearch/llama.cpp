# BodhiApp custom targets - include our Makefile
-include Makefile.bodhiapp

# Default target: show help
.DEFAULT_GOAL := help

help: ## Show all available targets with descriptions
	@echo '================================================'
	@echo '     BodhiApp llama.cpp - Available Targets'
	@echo '================================================'
	@echo ''
	@$(MAKE) -s help-bodhiapp