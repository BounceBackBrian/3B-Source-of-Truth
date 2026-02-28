export default function ContactPage() {
  return (
    <main className="container">
      <section className="glass">
        <p className="kicker">Start a Project</p>
        <h1>Tell Us What You Need Built</h1>
        <form className="form-grid">
          <label><span>Name</span><input name="name" required /></label>
          <label><span>Email</span><input name="email" type="email" required /></label>
          <label><span>Business Name</span><input name="businessName" required /></label>
          <label><span>Monthly Revenue Range</span><select name="revenue"><option>$0 - $10k</option><option>$10k - $50k</option><option>$50k+</option></select></label>
          <label><span>Need domain purchased/set up?</span><select name="domainSetup" required><option value="yes">Yes, please handle it</option><option value="no">No, domain already owned</option></select></label>
          <label><span>Primary Goal</span><select name="goal"><option>Lead Generation</option><option>E-commerce</option><option>Brand Authority</option></select></label>
          <label className="span-2"><span>Project Details</span><textarea name="message" rows={4} required /></label>
          <button className="btn btn-primary span-2" type="submit">Send Lead</button>
        </form>
      </section>
    </main>
  );
}
