import { Hero } from "@/sections/Hero";
import { WhatIsKova } from "@/sections/WhatIsKova";
import { WhatKovaDoes } from "@/sections/WhatKovaDoes";
import { HowItWorks } from "@/sections/HowItWorks";
import { ChildApp } from "@/sections/ChildApp";
import { Story } from "@/sections/Story";
import { CTA } from "@/sections/CTA";

export default function Home() {
  return (
    <main className="relative">
      <Hero />
      <WhatIsKova />
      <WhatKovaDoes />
      <HowItWorks />
      <ChildApp />
      <Story />
      <CTA />
    </main>
  );
}
