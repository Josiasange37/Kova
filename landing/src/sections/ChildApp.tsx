"use client";

import { useRef, useState, useEffect } from "react";
import { motion, useScroll, useInView } from "framer-motion";
import Image from "next/image";

interface Step {
  id: number;
  title: string;
  description: string;
  position: "left" | "right";
  top: string;
  image: string;
}

const childSteps: Step[] = [
  {
    id: 1,
    title: "Silent Installation",
    description: "One-time setup installs KOVA as a system service. No visible app icon, no notifications, completely invisible.",
    position: "right",
    top: "15%",
    image: "/child-install.png",
  },
  {
    id: 2,
    title: "Permission Granting",
    description: "Device Admin & Accessibility permissions enable full monitoring capabilities without root access.",
    position: "left",
    top: "30%",
    image: "/child-permissions.png",
  },
  {
    id: 3,
    title: "Background Operation",
    description: "KOVA runs silently 24/7. Monitors app usage, captures screenshots, and detects content in real-time.",
    position: "right",
    top: "45%",
    image: "/child-running.png",
  },
  {
    id: 4,
    title: "Tamper Protection",
    description: "Self-healing mechanisms prevent uninstallation. If detected, alerts parent immediately and reactivates.",
    position: "left",
    top: "60%",
    image: "/child-protected.png",
  },
  {
    id: 5,
    title: "Encrypted Sync",
    description: "Captured data encrypted locally, synced securely when connection available. Zero battery impact.",
    position: "right",
    top: "75%",
    image: "/child-sync.png",
  },
];

function StepLabel({ step, isActive, index }: { step: Step; isActive: boolean; index: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: step.position === "left" ? -50 : 50 }}
      animate={{ 
        opacity: isActive ? 1 : 0.3, 
        x: 0,
        scale: isActive ? 1 : 0.95
      }}
      transition={{ duration: 0.5, delay: index * 0.1 }}
      className={`absolute ${step.position === "left" ? "right-[55%] text-right" : "left-[55%] text-left"}`}
      style={{ top: step.top }}
    >
      <div 
        className={`absolute top-1/2 ${step.position === "left" ? "left-full ml-4" : "right-full mr-4"} w-12 lg:w-20 h-px bg-gradient-to-${step.position === "left" ? "r" : "l"} from-emerald-500 to-transparent`}
      >
        <div className={`absolute ${step.position === "left" ? "right-0" : "left-0"} top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-emerald-500 ${isActive ? "animate-pulse" : ""}`} />
      </div>

      <div className={`max-w-xs ${step.position === "left" ? "ml-auto" : "mr-auto"}`}>
        <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-emerald-100 text-emerald-600 text-sm font-bold mb-2">
          {step.id}
        </span>
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-1">{step.title}</h3>
        <p className={`text-sm text-gray-500 dark:text-gray-400 transition-all duration-300 ${isActive ? "max-h-20 opacity-100" : "max-h-0 opacity-0 overflow-hidden lg:max-h-20 lg:opacity-100"}`}>
          {step.description}
        </p>
      </div>
    </motion.div>
  );
}

export function ChildApp() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  const [activeStep, setActiveStep] = useState(0);
  const sectionInView = useInView(containerRef, { margin: "-20%" });

  useEffect(() => {
    const unsubscribe = scrollYProgress.on("change", (latest) => {
      const totalSteps = childSteps.length;
      const stepProgress = latest * totalSteps;
      const currentStep = Math.min(Math.floor(stepProgress), totalSteps - 1);
      setActiveStep(currentStep);
    });
    return () => unsubscribe();
  }, [scrollYProgress]);

  return (
    <section ref={containerRef} className="relative bg-[#f5f5f5] dark:bg-[#0a0a0a] transition-colors duration-500">
      <div className="sticky top-0 h-screen overflow-hidden">
        <div className="absolute inset-0 pointer-events-none">
          <div 
            className="absolute inset-0 opacity-30"
            style={{
              backgroundImage: `radial-gradient(circle at 50% 50%, rgba(16, 185, 129, 0.1) 0%, transparent 50%)`,
            }}
          />
          <div 
            className="absolute inset-0"
            style={{
              backgroundImage: `linear-gradient(rgba(0,0,0,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(0,0,0,0.02) 1px, transparent 1px)`,
              backgroundSize: '60px 60px'
            }}
          />
        </div>

        <div className="relative z-10 h-full max-w-7xl mx-auto px-6 lg:px-8">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={sectionInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="absolute top-8 left-0 right-0 text-center"
          >
            <span className="text-xs font-medium text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2 block">
              Child Device
            </span>
            <h2 className="text-3xl md:text-4xl font-light text-gray-900 dark:text-white">
              Silent <span className="font-semibold text-emerald-600">Protection</span>
            </h2>
            <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
              How KOVA operates invisibly on your child's device
            </p>
          </motion.div>

          <div className="absolute left-6 top-1/2 -translate-y-1/2 hidden lg:flex flex-col gap-2">
            {childSteps.map((_, i) => (
              <motion.div
                key={i}
                className="w-2 h-2 rounded-full transition-colors duration-300"
                animate={{ 
                  backgroundColor: i === activeStep ? "#10B981" : "#E5E7EB",
                  scale: i === activeStep ? 1.3 : 1
                }}
              />
            ))}
          </div>

          <div className="relative h-full flex items-center justify-center">
            <div className="absolute inset-0 pointer-events-none">
              {childSteps.map((step, i) => (
                <StepLabel 
                  key={step.id} 
                  step={step} 
                  isActive={i === activeStep}
                  index={i}
                />
              ))}
            </div>

            <motion.div
              className="relative z-20"
              animate={{ 
                y: activeStep % 2 === 0 ? 0 : 10,
                rotateY: activeStep % 2 === 0 ? 0 : -3
              }}
              transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            >
              <div className="relative w-[280px] h-[570px] md:w-[320px] md:h-[650px] bg-gray-900 rounded-[3rem] p-3 shadow-2xl shadow-emerald-500/10">
                <div className="relative w-full h-full bg-white rounded-[2.5rem] overflow-hidden">
                  {childSteps.map((step, i) => (
                    <motion.div
                      key={step.image}
                      className="absolute inset-0"
                      initial={{ opacity: 0, scale: 1.1 }}
                      animate={{ 
                        opacity: i === activeStep ? 1 : 0,
                        scale: i === activeStep ? 1 : 1.1,
                        x: i < activeStep ? -20 : i > activeStep ? 20 : 0
                      }}
                      transition={{ duration: 0.5 }}
                    >
                      <Image
                        src={step.image}
                        alt={step.title}
                        fill
                        className="object-cover"
                      />
                      <div className="absolute inset-0 flex items-center justify-center bg-gray-100 -z-10">
                        <span className="text-gray-400 text-sm">{step.image}</span>
                      </div>
                    </motion.div>
                  ))}

                  <div className="absolute top-4 left-1/2 -translate-x-1/2 flex gap-1">
                    {childSteps.map((_, i) => (
                      <div
                        key={i}
                        className={`w-1.5 h-1.5 rounded-full transition-colors ${i === activeStep ? "bg-emerald-500" : "bg-gray-300"}`}
                      />
                    ))}
                  </div>
                </div>

                <div className="absolute top-6 left-1/2 -translate-x-1/2 w-24 h-6 bg-gray-900 rounded-full" />
              </div>

              <div className="absolute -bottom-8 left-1/2 -translate-x-1/2 w-[200px] h-[20px] bg-gradient-to-t from-gray-900/20 to-transparent blur-xl rounded-full" />
            </motion.div>
          </div>

          <div className="absolute bottom-8 left-0 right-0 text-center">
            <span className="text-5xl font-light text-gray-200">
              {String(activeStep + 1).padStart(2, '0')}
            </span>
            <span className="text-5xl font-light text-gray-300">
              /{String(childSteps.length).padStart(2, '0')}
            </span>
          </div>
        </div>
      </div>

      <div className="h-[400vh]" />
    </section>
  );
}
