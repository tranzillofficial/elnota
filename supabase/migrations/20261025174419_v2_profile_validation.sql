create or replace function elnota_private.validate_v2_snapshot(p jsonb) returns void
language plpgsql immutable set search_path='' as $$
declare t text; pk text; r jsonb; allowed text[]; required text[]; k text;
begin
 if p is null or jsonb_typeof(p)<>'object' or p->>'schema_version' is distinct from '3' then raise exception 'SCHEMA_MISMATCH';end if;
 if octet_length(p::text)>10485760 then raise exception 'SNAPSHOT_TOO_LARGE';end if;
 if p ? 'business_profile' then
  if jsonb_typeof(p->'business_profile') is distinct from 'object' then raise exception 'INVALID_PROFILE';end if;
  if exists(select 1 from jsonb_each(p->'business_profile') e where e.key not in ('name','phone','address','logo') or (e.value<>'null'::jsonb and jsonb_typeof(e.value)<>'string') or length(e.value::text)>3000000) then raise exception 'INVALID_PROFILE';end if;
 end if;
 foreach t in array array['customers','product_categories','catalog_products','invoices','invoice_items','payments','invoice_terms','ledger_entries'] loop
  if jsonb_typeof(p->t) is distinct from 'array' then raise exception 'INVALID_TABLE:%',t;end if;

  allowed:=case t when 'customers' then array['id','workspace_id','name','phone','notes','version','created_at','updated_at','deleted_at'] when 'product_categories' then array['id','workspace_id','name','created_at','updated_at','version','deleted_at'] when 'catalog_products' then array['id','workspace_id','category_id','barcode','name','price_minor','image_webp','description','created_at','updated_at','version','deleted_at'] when 'invoices' then array['id','workspace_id','customer_id','invoice_number','status','total_minor','discount_minor','notes','is_manual_amount','invoice_date','due_date','version','created_at','updated_at','deleted_at'] when 'invoice_items' then array['id','invoice_id','product_id','description','quantity','unit_price_minor','discount_minor','created_at'] when 'payments' then array['id','workspace_id','customer_id','amount_minor','notes','payment_date','idempotency_key','version','created_at','updated_at','deleted_at'] when 'invoice_terms' then array['invoice_id','workspace_id','customer_id','method','upfront_minor','months','first_due_date'] when 'ledger_entries' then array['id','workspace_id','customer_id','source_id','event_type','amount_minor','notes','occurred_at','created_at'] end;
  required:=case t when 'customers' then array['id','workspace_id','name','version','created_at','updated_at'] when 'product_categories' then array['id','workspace_id','name','created_at','updated_at','version'] when 'catalog_products' then array['id','workspace_id','category_id','barcode','name','price_minor','created_at','updated_at','version'] when 'invoices' then array['id','workspace_id','customer_id','status','total_minor','discount_minor','is_manual_amount','invoice_date','version','created_at','updated_at'] when 'invoice_items' then array['id','invoice_id','description','quantity','unit_price_minor','discount_minor','created_at'] when 'payments' then array['id','workspace_id','customer_id','amount_minor','payment_date','idempotency_key','version','created_at','updated_at'] when 'invoice_terms' then array['invoice_id','workspace_id','customer_id','method','upfront_minor','months','first_due_date'] when 'ledger_entries' then array['id','workspace_id','customer_id','source_id','event_type','amount_minor','occurred_at','created_at'] end;
  foreach r in array array(select x from jsonb_array_elements(p->t) x) loop
   if not (r ?& required) or exists(select 1 from jsonb_object_keys(r) key where not key=any(allowed)) then raise exception 'INVALID_FIELDS:%',t;end if;
   foreach k in array required loop if r->k='null'::jsonb then raise exception 'REQUIRED_FIELD:%',k;end if;end loop;
   foreach k in array allowed loop
    if r->k is null or r->k='null'::jsonb then continue;end if;
    if k like '%_minor' or k in ('quantity','version','created_at','updated_at','deleted_at','invoice_date','due_date','payment_date','occurred_at','first_due_date','months','is_manual_amount') then
     if jsonb_typeof(r->k)<>'number' or (r->>k) !~ '^-?[0-9]+$' then raise exception 'INVALID_INTEGER:%',k;end if;
    elsif jsonb_typeof(r->k)<>'string' then raise exception 'INVALID_TEXT:%',k;end if;
   end loop;
  end loop;
  pk:=case when t='invoice_terms' then 'invoice_id' else 'id' end;
  if exists(select 1 from jsonb_array_elements(p->t) x where jsonb_typeof(x)<>'object' or jsonb_typeof(x->pk) is distinct from 'string' or length(x->>pk)=0) then raise exception 'INVALID_ID:%',t;end if;
  if exists(select 1 from jsonb_array_elements(p->t) x group by x->>pk having count(*)>1) then raise exception 'DUPLICATE_ID:%',t;end if;
  if t<>'invoice_items' and exists(select 1 from jsonb_array_elements(p->t) x where x->>'workspace_id' is distinct from 'default') then raise exception 'WORKSPACE_MISMATCH';end if;
  -- Exact integer money values only; PostgreSQL numeric avoids overflow during validation.
  if exists(select 1 from jsonb_array_elements(p->t) x cross join lateral jsonb_each(x) e where e.key like '%_minor' and (jsonb_typeof(e.value)<>'number' or e.value::text !~ '^-?[0-9]+$' or abs((e.value::text)::numeric)>9007199254740991)) then raise exception 'INVALID_MONEY';end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p->'customers') x where jsonb_typeof(x->'name') is distinct from 'string' or length(trim(x->>'name'))=0) then raise exception 'INVALID_CUSTOMER';end if;
 foreach t in array array['invoices','payments','ledger_entries','invoice_terms'] loop
  if exists(select 1 from jsonb_array_elements(p->t) x where not exists(select 1 from jsonb_array_elements(p->'customers') c where c->>'id'=x->>'customer_id')) then raise exception 'CUSTOMER_MISSING';end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p->'invoice_items') x where not exists(select 1 from jsonb_array_elements(p->'invoices') i where i->>'id'=x->>'invoice_id') or x->>'quantity' !~ '^[1-9][0-9]*$' or (x->>'unit_price_minor')::numeric<0 or (x->>'discount_minor')::numeric<0 or (x->>'discount_minor')::numeric>(x->>'quantity')::numeric*(x->>'unit_price_minor')::numeric) then raise exception 'INVALID_ITEM';end if;
 if exists(select 1 from jsonb_array_elements(p->'catalog_products') x where not exists(select 1 from jsonb_array_elements(p->'product_categories') c where c->>'id'=x->>'category_id') or length(trim(x->>'name'))=0 or length(trim(x->>'barcode'))=0 or (x->>'price_minor')::numeric<0) then raise exception 'INVALID_PRODUCT';end if;
 if exists(select 1 from jsonb_array_elements(p->'catalog_products') x where x->>'image_webp' is not null and (octet_length(decode(x->>'image_webp','base64'))>524288 or substring(decode(x->>'image_webp','base64') from 1 for 4)<>convert_to('RIFF','UTF8') or substring(decode(x->>'image_webp','base64') from 9 for 4)<>convert_to('WEBP','UTF8'))) then raise exception 'INVALID_IMAGE';end if;
 if exists(select 1 from jsonb_array_elements(p->'catalog_products') x where x->>'deleted_at' is null group by lower(x->>'barcode') having count(*)>1) then raise exception 'DUPLICATE_BARCODE';end if;
 if exists(select 1 from jsonb_array_elements(p->'product_categories') x where x->>'deleted_at' is null group by lower(x->>'name') having count(*)>1) then raise exception 'DUPLICATE_CATEGORY';end if;
 foreach r in array array(select x from jsonb_array_elements(p->'invoices') x) loop
  if r->>'status' not in ('posted','draft','voided') or r->>'status' is null or (r->>'total_minor')::numeric<0 or (r->>'discount_minor')::numeric<0 or (r->>'discount_minor')::numeric>(r->>'total_minor')::numeric then raise exception 'INVALID_INVOICE';end if;
  if not ((r->>'is_manual_amount')='1' and not exists(select 1 from jsonb_array_elements(p->'invoice_items') l where l->>'invoice_id'=r->>'id')) and
   (r->>'total_minor')::numeric<>(select coalesce(sum((l->>'quantity')::numeric*(l->>'unit_price_minor')::numeric-(l->>'discount_minor')::numeric),0) from jsonb_array_elements(p->'invoice_items') l where l->>'invoice_id'=r->>'id') then raise exception 'INVOICE_TOTAL_MISMATCH';end if;
  if r->>'status'='posted' and (select count(*)<>1 or coalesce(sum((l->>'amount_minor')::numeric),0)<>(r->>'total_minor')::numeric-(r->>'discount_minor')::numeric from jsonb_array_elements(p->'ledger_entries') l where l->>'source_id'=r->>'id' and l->>'event_type'='invoice_charge' and l->>'customer_id'=r->>'customer_id') then raise exception 'CHARGE_MISMATCH';end if;
 end loop;
 foreach r in array array(select x from jsonb_array_elements(p->'payments') x) loop
  if (r->>'amount_minor')::numeric<=0 or (select count(*)<>1 or coalesce(sum((l->>'amount_minor')::numeric),0)<>-(r->>'amount_minor')::numeric from jsonb_array_elements(p->'ledger_entries') l where l->>'source_id'=r->>'id' and l->>'event_type'='payment_receipt' and l->>'customer_id'=r->>'customer_id') then raise exception 'RECEIPT_MISMATCH';end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p->'payments') x group by x->>'idempotency_key' having count(*)>1) then raise exception 'DUPLICATE_PAYMENT_KEY';end if;
 if exists(select 1 from jsonb_array_elements(p->'ledger_entries') x group by x->>'source_id',x->>'event_type' having count(*)>1) then raise exception 'DUPLICATE_LEDGER_SOURCE';end if;
 if exists(select 1 from jsonb_array_elements(p->'ledger_entries') x where x->>'event_type' not in ('invoice_charge','payment_receipt') or (x->>'event_type'='invoice_charge' and not exists(select 1 from jsonb_array_elements(p->'invoices') i where i->>'id'=x->>'source_id' and i->>'status'='posted' and i->>'customer_id'=x->>'customer_id')) or (x->>'event_type'='payment_receipt' and not exists(select 1 from jsonb_array_elements(p->'payments') i where i->>'id'=x->>'source_id' and i->>'customer_id'=x->>'customer_id'))) then raise exception 'INVALID_LEDGER_SOURCE';end if;
 if exists(select 1 from jsonb_array_elements(p->'invoice_terms') x where not exists(select 1 from jsonb_array_elements(p->'invoices') i where i->>'id'=x->>'invoice_id' and i->>'customer_id'=x->>'customer_id') or x->>'method' not in ('cash','credit','installments') or (x->>'months')::int not between 1 and 120 or (x->>'upfront_minor')::numeric<0) then raise exception 'INVALID_TERMS';end if;
end;$$;
revoke all on function elnota_private.validate_v2_snapshot(jsonb) from public,anon,authenticated;

