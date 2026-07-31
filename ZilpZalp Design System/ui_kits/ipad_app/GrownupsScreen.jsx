const { TopBar, Card, SettingRow, Button, Badge } = window.ZilpZalpDesignSystem_bd8c6b;

/* The only screen with small type, switches and full sentences. */
function GrownupsScreen({ go }) {
  const [sound, setSound] = React.useState(true);
  const [music, setMusic] = React.useState(false);
  const [names, setNames] = React.useState(true);
  return (
    <div style={{ minHeight: '100%', background: 'var(--surface-page)' }}>
      <TopBar onBack={() => go('home')} title="Für Erwachsene" />
      <div style={{ maxWidth: 'var(--max-content)', margin: '0 auto', padding: 'var(--space-6) var(--gutter-screen)' }}>
        <p style={{ font: 'var(--weight-semibold) var(--text-body-lg)/var(--lh-body-lg) var(--font-body)', color: 'var(--text-body)', marginTop: 0 }}>
          ZilpZalp lernt Vögel über Rufe und Bilder — ohne Lesen, ohne Punktejagd. Hier stellen Sie ein, wie lange und wie laut gespielt wird.
        </p>
        <Card pad="0" style={{ overflow: 'hidden', marginBottom: 'var(--space-6)' }}>
          <SettingRow icon="volume-2" label="Vogelstimmen" hint="Echte Aufnahmen aus der Sammlung" on={sound} onToggle={() => setSound(!sound)} />
          <SettingRow icon="music" label="Hintergrundmusik" hint="Leise Waldgeräusche zwischen den Runden" on={music} onToggle={() => setMusic(!music)} />
          <SettingRow icon="type" label="Namen anzeigen" hint="Vogelnamen unter den Bildern einblenden" on={names} onToggle={() => setNames(!names)} />
          <SettingRow icon="clock" label="Spielzeit pro Tag" value="20 Min" />
          <SettingRow icon="languages" label="Sprache" value="Deutsch" />
          <SettingRow icon="camera" label="Fotos & Dank" hint="Alle Vogelfotos von iNaturalist, CC BY — Namensnennung" value={(window.ZZ_BIRDS || []).length + " Fotos"} style={{ borderBottom: 'none' }} />
        </Card>
        <Card pad="var(--space-5)" tone="sand" style={{ marginBottom: 'var(--space-6)' }}>
          <div style={{ font: 'var(--weight-bold) var(--text-headline)/1.2 var(--font-display)', color: 'var(--text-strong)', marginBottom: 'var(--space-3)' }}>Fotos &amp; Dank</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px 24px' }}>
            {(window.ZZ_BIRDS || []).map(b => (
              <div key={b.slug} style={{ display: 'flex', justifyContent: 'space-between', gap: 'var(--space-4)', font: 'var(--weight-semibold) var(--text-caption)/1.5 var(--font-body)', color: 'var(--text-muted)', borderBottom: '2px solid var(--sand-300)', paddingBottom: 4 }}>
                <span style={{ color: 'var(--text-strong)' }}>{b.name}</span><span>{b.credit}</span>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 'var(--space-4)', font: 'var(--weight-semibold) var(--text-caption)/1.5 var(--font-body)', color: 'var(--text-muted)' }}>Quelle: iNaturalist, Lizenz CC BY 4.0. Details in assets/photos/CREDITS.md</div>
        </Card>
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-4)' }}>
          <Badge tone="sand" icon="shield-check">Keine Werbung, keine Käufe</Badge>
          <Button tone="quiet" size="md" icon="chevron-left" onClick={() => go('home')}>Zurück zum Spiel</Button>
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { GrownupsScreen });
