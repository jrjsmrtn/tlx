# TLx Makefile

# Architecture-as-Code targets
.PHONY: validate-architecture view-architecture export-architecture

validate-architecture:
	@echo "Validating architecture model..."
	podman run --rm \
		-v "$(PWD):/usr/local/structurizr" \
		-w /usr/local/structurizr/architecture \
		structurizr/cli validate -workspace workspace.dsl

view-architecture:
	@echo "Starting Structurizr Lite on http://localhost:8080..."
	@echo "Press Ctrl+C to stop"
	podman run --rm -p 8080:8080 \
		-v "$(PWD):/usr/local/structurizr" \
		-e STRUCTURIZR_WORKSPACE_PATH=architecture \
		structurizr/lite

export-architecture:
	@echo "Exporting architecture to PlantUML..."
	podman run --rm \
		-v "$(PWD):/usr/local/structurizr" \
		-w /usr/local/structurizr/architecture \
		structurizr/cli export -workspace workspace.dsl -format plantuml -output diagrams/
