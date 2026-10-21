import {createClient} from 'npm:@supabase/supabase-js@2.117.3';
import {passwordHandler} from './handler.mjs';
Deno.serve(passwordHandler(createClient,key=>Deno.env.get(key)));
