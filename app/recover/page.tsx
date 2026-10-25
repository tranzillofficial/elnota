import Recovery from './recovery';
import type { Metadata } from 'next';
export const metadata:Metadata={title:'استرجاع بيانات النسخة السابقة',robots:{index:false,follow:false}};
export default function Page(){return <Recovery/>}
