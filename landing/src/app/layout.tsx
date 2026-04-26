import type { Metadata } from "next";
import "./globals.css";
import { SmoothScroll } from "@/components/SmoothScroll";
import { Footer } from "@/components/Footer";
import { ThemeProvider } from "@/components/ThemeProvider";

export const metadata: Metadata = {
  title: "KOVA — Smart Child Monitoring",
  description: "Next-generation offline-first, zero-knowledge encrypted child protection. Invisible system service that survives aggressive battery optimization.",
  keywords: ["child protection", "parental control", "android monitoring", "digital safety", "privacy"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased bg-[#f5f5f5] dark:bg-[#0a0a0a] overflow-x-hidden transition-colors duration-500">
        <ThemeProvider>
          <SmoothScroll>
            {children}
            <Footer />
          </SmoothScroll>
        </ThemeProvider>
      </body>
    </html>
  );
}
