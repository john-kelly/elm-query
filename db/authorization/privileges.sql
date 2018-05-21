-- this file contains the privileges of all aplications roles to each database entity
\echo # Loading roles privilege

-- specify which application roles can access this api
grant usage on schema api to anonymous;

grant select, insert, update, delete on api.pokemons to anonymous;

grant select, insert, update, delete on api.trainers to anonymous;

grant select, insert, update, delete on api.captures to anonymous;
