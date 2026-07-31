const { TopBar, QuizProgress, ChoiceTile, SoundButton, FeedbackBanner, Button } = window.ZilpZalpDesignSystem_bd8c6b;

const B = (slug) => (window.ZZ_BIRDS || []).find(b => b.slug === slug) || {};
const ROUND = [
  { ...B('zilpzalp'), tone: 'wald', ok: true },
  { ...B('amsel'), tone: 'beeren' },
  { ...B('wiedehopf'), tone: 'rufe' },
  { ...B('blaumeise'), tone: 'sumpf' },
];

/* Listen to the call, tap the bird. No words needed to play. */
function QuizScreen({ go, onScore }) {
  const [picked, setPicked] = React.useState(null);
  const [playing, setPlaying] = React.useState(true);
  React.useEffect(() => { const t = setTimeout(() => setPlaying(false), 2600); return () => clearTimeout(t); }, [playing]);
  const right = picked !== null && ROUND[picked].ok;

  const pick = (i) => {
    if (right) return;
    setPicked(i);
    if (ROUND[i].ok) onScore();
  };

  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column', background: 'var(--surface-page)' }}>
      <TopBar onBack={() => go('home')} onSettings={() => go('grownups')} center={<QuizProgress total={5} done={2} current={2} />} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '20px var(--gutter-screen) 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-6)', marginBottom: 18 }}>
          <SoundButton playing={playing} size={150} onClick={() => setPlaying(true)} />
          <h1 style={{ margin: 0, font: 'var(--weight-black) var(--text-display-2)/var(--lh-display-2) var(--font-display)', color: 'var(--text-strong)' }}>Wer singt da?</h1>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--gap-tiles)', width: '100%' }}>
          {ROUND.map((b, i) => (
            <ChoiceTile key={b.name} name={b.name} photo={b.photo} credit={b.credit} tone={b.tone} size={230}
              state={picked === i ? (b.ok ? 'correct' : 'retry') : 'idle'}
              dimmed={right && !b.ok}
              onSelect={() => pick(i)} />
          ))}
        </div>
        <div style={{ minHeight: 100, display: 'flex', alignItems: 'center', gap: 'var(--space-5)', marginTop: 'var(--space-5)' }}>
          {picked === null ? null : right
            ? (<><FeedbackBanner tone="correct">Genau! Das ist der Zilpzalp.</FeedbackBanner><Button tone="primary" iconRight="arrow-right" onClick={() => go('reward')}>Weiter</Button></>)
            : (<FeedbackBanner tone="retry">Fast! Hör nochmal hin.</FeedbackBanner>)}
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { QuizScreen });
