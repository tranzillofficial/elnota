import Link from 'next/link';
import { NotebookPen } from 'lucide-react';
export function Brand(){return <Link href="/" className="brand"><span className="brand-icon"><NotebookPen size={25}/></span><span>النوتة<small>ELNOTA</small></span></Link>}
