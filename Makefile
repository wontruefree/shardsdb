DATABASE_NAME ?= $(shell echo $(SHARDSDB_DATABASE) | grep -o -P '[^/]+$$')
TEST_DATABASE_NAME ?= $(shell echo $(SHARDSDB_TEST_DATABASE) | grep -o -P '[^/]+$$')
PG_USER ?= postgres

.PHONY: SHARDSDB_DATABASE
SHARDSDB_DATABASE:
	@test "${$@}" || (echo "$@ is undefined" && false)

.PHONY: SHARDSDB_TEST_DATABASE
SHARDSDB_TEST_DATABASE:
	@test "${$@}" || (echo "$@ is undefined" && false)

.PHONY: test_db
test_db: SHARDSDB_TEST_DATABASE
	@psql $(TEST_DATABASE_NAME) -c "SELECT 1" > /dev/null 2>&1 || \
	(createdb -U $(PG_USER) $(TEST_DATABASE_NAME) && psql -U $(PG_USER) $(TEST_DATABASE_NAME) < db/schema.sql)

.PHONY: db
db: SHARDSDB_DATABASE
	@psql $(DATABASE_NAME) -c "SELECT 1" > /dev/null 2>&1 || \
	createdb -U $(PG_USER) $(DATABASE_NAME)
	psql -U $(PG_USER) $(DATABASE_NAME) < db/schema.sql

.PHONY: db/dump_schema
db/dump_schema: SHARDSDB_DATABASE
	pg_dump -U $(PG_USER) -s $(DATABASE_NAME) > db/schema.sql

.PHONY: test
test: test_db
	crystal spec

catalog:
	crystal run scripts/awesome-list.cr

.PHONY: test_db/drop_sync
test_db/drop_sync:
	dropdb -U $(PG_USER) $(TEST_DATABASE_NAME) || true
	createdb -U $(PG_USER) $(TEST_DATABASE_NAME) 2> /dev/null
	pg_dump -U $(PG_USER) -s $(DATABASE_NAME) | psql -U $(PG_USER) $(TEST_DATABASE_NAME) -q
