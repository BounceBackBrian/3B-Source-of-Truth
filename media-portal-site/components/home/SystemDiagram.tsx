export function SystemDiagram() {
  const layers = ['Public Website', 'Client Portal', 'Admin Portal', 'Payments (3Boost)', 'Governance + Audit'];

  return (
    <section className="glass">
      <h2 className="section-title">One Platform. Multiple Layers. Total Control.</h2>
      <div className="system-layers">
        {layers.map((layer) => (
          <div key={layer} className="system-node">{layer}</div>
        ))}
      </div>
    </section>
  );
}
