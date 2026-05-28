insert into user_logins (user_id, last_login)
values (?, now())
on conflict (user_id) do update set last_login = now();

-- refine: do update last_login eq to insert last_login. (excluded)
insert into user_logins (user_id, last_login)
values (?, now())
on conflict (user_id) do update set last_login = excluded.last_login;