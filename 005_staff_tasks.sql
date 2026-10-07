-- Enables ITP teachers and educators/support teachers to share tasks and record work.
alter table public.work_tasks
 add column if not exists created_by_name text not null default 'Referente';

create or replace function private.set_work_task_creator_name()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 select m.username into new.created_by_name
 from public.company_members m
 where m.company_id=new.company_id and m.user_id=new.created_by;
 if new.created_by_name is null then new.created_by_name:='Personale'; end if;
 return new;
end; $$;
revoke all on function private.set_work_task_creator_name() from public,anon,authenticated;
drop trigger if exists work_tasks_set_creator_name on public.work_tasks;
create trigger work_tasks_set_creator_name before insert on public.work_tasks
 for each row execute function private.set_work_task_creator_name();

drop policy if exists "staff read tasks" on public.work_tasks;
create policy "staff read tasks" on public.work_tasks for select to authenticated
 using(private.has_company_role(company_id,array['owner','referente','itp','richiedente']));

drop policy if exists "staff create tasks" on public.work_tasks;
create policy "staff create tasks" on public.work_tasks for insert to authenticated
 with check(created_by=(select auth.uid()) and status='Da fare'
 and private.has_company_role(company_id,array['itp','richiedente']));

drop policy if exists "admins and author read work logs" on public.work_logs;
create policy "admins and author read work logs" on public.work_logs for select to authenticated
 using((staff_id=(select auth.uid()) and private.has_company_role(company_id,array['itp','richiedente']))
 or private.has_company_role(company_id,array['owner','referente']));

drop policy if exists "itp records own work" on public.work_logs;
drop policy if exists "staff records own work" on public.work_logs;
create policy "staff records own work" on public.work_logs for insert to authenticated
 with check(staff_id=(select auth.uid()) and private.has_company_role(company_id,array['itp','richiedente'])
 and (task_id is null or exists(
  select 1 from public.work_tasks t where t.id=task_id and t.company_id=work_logs.company_id
 )));
