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

// Keep the window in view while the descriptions advance. Appearance is entirely CSS-driven.
const windowStory = document.querySelector('.window-story');
if (windowStory) {
  const steps = [...windowStory.querySelectorAll('.story-step')];
  const slides = [...windowStory.querySelectorAll('.window-slide')];
  const compact = window.matchMedia('(max-width: 720px)');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let updatePending = false;

  function updateWindowStory() {
    updatePending = false;
    const readingLine = window.innerHeight * (compact.matches ? 0.78 : 0.5);
    const centers = steps.map(step => {
      const rect = step.getBoundingClientRect();
      return rect.top + rect.height / 2;
    });
    let progress = 0;
    for (let index = 0; index < centers.length - 1; index++) {
      if (readingLine < centers[index]) break;
      const distance = centers[index + 1] - centers[index];
      const fraction = Math.max(0, Math.min(1, (readingLine - centers[index]) / distance));
      // Hold each window long enough to read it, then blend through the middle of the scroll.
      const blend = Math.max(0, Math.min(1, (fraction - 0.3) / 0.4));
      progress = index + blend * blend * (3 - 2 * blend);
    }
    const active = Math.round(progress);
    for (const [index, slide] of slides.entries()) {
      const opacity = reducedMotion.matches
        ? Number(index === active)
        : Math.max(0, 1 - Math.abs(progress - index));
      slide.style.opacity = String(opacity);
      slide.style.pointerEvents = index === active ? 'auto' : 'none';
      slide.setAttribute('aria-hidden', String(index !== active));
      for (const link of slide.querySelectorAll('a')) link.tabIndex = index === active ? 0 : -1;
    }
  }

  function queueWindowStoryUpdate() {
    if (updatePending) return;
    updatePending = true;
    requestAnimationFrame(updateWindowStory);
  }

  windowStory.classList.add('is-scroll-story');
  window.addEventListener('scroll', queueWindowStoryUpdate, {passive: true});
  window.addEventListener('resize', queueWindowStoryUpdate);
  reducedMotion.addEventListener('change', queueWindowStoryUpdate);
  updateWindowStory();
}
