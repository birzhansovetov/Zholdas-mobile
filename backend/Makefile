.PHONY: run test build db-start db-stop sqlc

run:
	go run cmd/server/main.go

test:
	go test -v ./...

build:
	go build -o server cmd/server/main.go

sqlc:
	~/go/bin/sqlc generate

db-start:
	/Applications/Postgres.app/Contents/Versions/latest/bin/pg_ctl -D '/Users/birzhansovetov/Desktop/Zholdas Mobail/postgres_data' -l '/Users/birzhansovetov/Desktop/Zholdas Mobail/postgres_data/postgres.log' start

db-stop:
	/Applications/Postgres.app/Contents/Versions/latest/bin/pg_ctl -D '/Users/birzhansovetov/Desktop/Zholdas Mobail/postgres_data' stop
