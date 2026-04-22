all: format lint

format:
	swiftformat .

lint:
	swiftlint --fix
