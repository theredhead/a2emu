// Keep the small-screen FAQ readable: opening one answer closes its siblings.
const answers = [...document.querySelectorAll('.questions details')];
for (const answer of answers) {
  answer.addEventListener('toggle', () => {
    if (!answer.open || !window.matchMedia('(max-width: 720px)').matches) return;
    for (const other of answers) if (other !== answer) other.open = false;
  });
}

// One opaque identifier per browser-tab session. Nothing is sent to third parties.
async function refreshCounters() {
  const display=document.querySelector('[data-counters]');
  if(!display)return;
  try {
    let session;
    try {
      session=sessionStorage.getItem('a2emu-session');
      if(!session){session=crypto.randomUUID();sessionStorage.setItem('a2emu-session',session);}
    } catch {session=crypto.randomUUID();}
    await fetch('/api/visit',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({session}),credentials:'omit'});
    const response=await fetch('/api/stats',{credentials:'omit'});
    if(!response.ok)return;
    const counts=await response.json();
    if(!Number.isFinite(counts.visits)||!Number.isFinite(counts.builderDownloads))return;
    const format=new Intl.NumberFormat();
    display.textContent=`${format.format(counts.visits)} visits · ${format.format(counts.builderDownloads)} builder downloads`;
    display.hidden=false;
  } catch { /* Downloads and the page remain usable if counters are unavailable. */ }
}
refreshCounters();

// Repeat the strip for a seamless marquee; keep duplicate links out of keyboard navigation.
const marquee=document.querySelector('.gallery-viewport');
if(marquee){
  const strip=marquee.querySelector('.screenshot-gallery');
  const reduced=window.matchMedia('(prefers-reduced-motion: reduce)');
  for(const figure of [...strip.children]){
    const copy=figure.cloneNode(true);copy.setAttribute('aria-hidden','true');
    for(const link of copy.querySelectorAll('a'))link.tabIndex=-1;
    strip.append(copy);
  }
  function motion(){
    marquee.classList.toggle('is-animated',!reduced.matches);
  }
  reduced.addEventListener('change',motion);motion();
}
