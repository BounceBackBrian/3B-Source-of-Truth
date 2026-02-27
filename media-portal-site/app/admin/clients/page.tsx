import Link from 'next/link';

export default function AdminClientsPage() {
  return (
    <main className="container">
      <section className="glass">
        <h1>Client Directory</h1>
        <p>Review clients by business and open detailed governance profiles.</p>
        <Link className="btn btn-secondary" href="/admin/clients/demo">Open Demo Client</Link>
      </section>
    </main>
  );
}
