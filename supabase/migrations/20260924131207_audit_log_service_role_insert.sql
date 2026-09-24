-- audit_log_row() (the row-DML trigger) never needed this — it's security definer, so it
-- inserts as its owner regardless of the invoking role's own grants. But rule 16 also
-- requires logging non-DML events (an admin viewing/downloading a KYC file isn't a row
-- change), which the KYC Edge Functions write directly using the service_role client —
-- that needs an actual INSERT grant, which nothing has needed until now.
grant insert on public.audit_log to service_role;
