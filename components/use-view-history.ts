'use client';
import {useEffect,useRef} from 'react';
/** Keep only opaque indexes in browser history; view data stays in memory. */
export function useViewHistory<T>(view:T,key:string,root:T,rootKey:string,restore:(v:T)=>void,ready:boolean){
 const state=useRef<{views:{key:string;value:T}[];index:number;pending:boolean}|null>(null);
 const restoreRef=useRef(restore);restoreRef.current=restore;
 useEffect(()=>{if(!ready)return;
  if(!state.current){state.current={views:[{key:rootKey,value:root}],index:0,pending:false};history.replaceState({...history.state,elnotaView:0},'');}
  const pop=(event:PopStateEvent)=>{const s=state.current!;const index=event.state?.elnotaView;if(typeof index!=='number'||!s.views[index])return;s.index=index;s.pending=false;restoreRef.current(s.views[index].value)};
  window.addEventListener('popstate',pop);return()=>window.removeEventListener('popstate',pop);
 },[ready]);
 useEffect(()=>{const s=state.current;if(!ready||!s||s.pending)return;
  if(s.views[s.index].key===key){s.views[s.index].value=view;return;}
  const previous=s.views.slice(0,s.index).findLastIndex(x=>x.key===key);
  if(previous>=0){s.pending=true;history.go(previous-s.index);return;}
  s.views=s.views.slice(0,s.index+1);s.views.push({key,value:view});s.index++;
  history.pushState({...history.state,elnotaView:s.index},'');
 },[key,ready]);
}
