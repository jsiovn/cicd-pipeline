import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "cicd-pipeline web",
  description: "The Next.js app of the cicd-pipeline demo repo",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="vi">
      <body>{children}</body>
    </html>
  );
}
