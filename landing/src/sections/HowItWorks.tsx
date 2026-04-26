"use client";

import { useRef, useState, useEffect } from "react";
import { motion, useScroll, useTransform, useInView } from "framer-motion";
import Image from "next/image";

interface Step {
  id: number;
  title: string;
  description: string;
  position: "left" | "right";
  top: string;
  image: string;
}

const parentSteps: Step[] = [
  {
    id: 1,
    title: "Secure Sign In",
    description: "Access your dashboard with biometric authentication or secure credentials. All data is encrypted and synced.",
    position: "left",
    top: "15%",
    image: "/parent-signin.png",
  },
  {
    id: 2,
    title: "Dashboard Overview",
    description: "Real-time monitoring of all activities. View recent alerts, device status, and quick actions at a glance.",
    position: "right",
    top: "25%",
    image: "/parent-dashboard.png",
  },
  {
    id: 3,
    title: "Alert History",
    description: "Review all triggered alerts with timestamps. Filter by severity, app type, or date range for quick analysis.",
    position: "left",
    top: "40%",
    image: "/parent-alerts.png",
  },
  {
    id: 4,
    title: "Monitored Apps",
    description: "Full list of tracked applications. Enable or disable monitoring per app with granular control settings.",
    position: "right",
    top: "55%",
    image: "/parent-apps.png",
  },
  {
    id: 5,
    title: "Settings & Controls",
    description: "Configure sensitivity levels, sync intervals, and emergency lock features. Export data or manage devices.",
    position: "left",
    top: "70%",
    image: "/parent-settings.png",
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
      {/* Connection line */}
      <div 
        className={`absolute top-1/2 ${step.position === "left" ? "left-full ml-4" : "right-full mr-4"} w-12 lg:w-20 h-px bg-gradient-to-${step.position === "left" ? "r" : "l"} from-indigo-500 to-transparent`}
      >
        <div className={`absolute ${step.position === "left" ? "right-0" : "left-0"} top-1/2 -translate-y-1/2 w-2 h-2 rounded-full bg-indigo-500 ${isActive ? "animate-pulse" : ""}`} />
      </div>

      <div className={`max-w-xs ${step.position === "left" ? "ml-auto" : "mr-auto"}`}>
        <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-indigo-100 text-indigo-600 text-sm font-bold mb-2">
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

export function HowItWorks() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  const [activeStep, setActiveStep] = useState(0);
  const sectionInView = useInView(containerRef, { margin: "-20%" });

  // Track scroll progress for step switching
  useEffect(() => {
    const unsubscribe = scrollYProgress.on("change", (latest) => {
      const totalSteps = parentSteps.length;
      const stepProgress = latest * totalSteps;
      const currentStep = Math.min(Math.floor(stepProgress), totalSteps - 1);
      setActiveStep(currentStep);
    });
    return () => unsubscribe();
  }, [scrollYProgress]);

  return (
    <section ref={containerRef} className="relative bg-[#f5f5f5] dark:bg-[#0a0a0a] transition-colors duration-500">
      {/* Sticky container - extends height for scroll animation */}
      <div className="sticky top-0 h-screen overflow-hidden">
        {/* Background */}
        <div className="absolute inset-0 pointer-events-none">
          <div 
            className="absolute inset-0 opacity-30"
            style={{
              backgroundImage: `radial-gradient(circle at 50% 50%, rgba(99, 102, 241, 0.1) 0%, transparent 50%)`,
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
          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={sectionInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="absolute top-8 left-0 right-0 text-center"
          >
            <span className="text-xs font-medium text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2 block">
              Parent App
            </span>
            <h2 className="text-3xl md:text-4xl font-light text-gray-900 dark:text-white">
              How It <span className="font-semibold text-indigo-600">Works</span>
            </h2>
            <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
              Scroll to explore the parent monitoring experience
            </p>
          </motion.div>

          {/* Progress indicator */}
          <div className="absolute left-6 top-1/2 -translate-y-1/2 hidden lg:flex flex-col gap-2">
            {parentSteps.map((_, i) => (
              <motion.div
                key={i}
                className="w-2 h-2 rounded-full transition-colors duration-300"
                animate={{ 
                  backgroundColor: i === activeStep ? "#6366F1" : "#E5E7EB",
                  scale: i === activeStep ? 1.3 : 1
                }}
              />
            ))}
          </div>

          {/* Main content area */}
          <div className="relative h-full flex items-center justify-center">
            {/* Step labels */}
            <div className="absolute inset-0 pointer-events-none">
              {parentSteps.map((step, i) => (
                <StepLabel 
                  key={step.id} 
                  step={step} 
                  isActive={i === activeStep}
                  index={i}
                />
              ))}
            </div>

            {/* Center Phone */}
            <motion.div
              className="relative z-20"
              animate={{ 
                y: activeStep % 2 === 0 ? 0 : 10,
                rotateY: activeStep % 2 === 0 ? 0 : 3
              }}
              transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            >
              {/* Phone frame */}
              <div className="relative w-[280px] h-[570px] md:w-[320px] md:h-[650px] bg-gray-900 rounded-[3rem] p-3 shadow-2xl shadow-indigo-500/10">
                {/* Screen */}
                <div className="relative w-full h-full bg-white rounded-[2.5rem] overflow-hidden">
                  {parentSteps.map((step, i) => (
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
                      {/* Placeholder text */}
                      <div className="absolute inset-0 flex items-center justify-center bg-gray-100 -z-10">
                        <span className="text-gray-400 text-sm">{step.image}</span>
                      </div>
                    </motion.div>
                  ))}

                  {/* Active step indicator */}
                  <div className="absolute top-4 left-1/2 -translate-x-1/2 flex gap-1">
                    {parentSteps.map((_, i) => (
                      <div
                        key={i}
                        className={`w-1.5 h-1.5 rounded-full transition-colors ${i === activeStep ? "bg-indigo-500" : "bg-gray-300"}`}
                      />
                    ))}
                  </div>
                </div>

                {/* Notch */}
                <div className="absolute top-6 left-1/2 -translate-x-1/2 w-24 h-6 bg-gray-900 rounded-full" />
              </div>

              {/* Reflection */}
              <div className="absolute -bottom-8 left-1/2 -translate-x-1/2 w-[200px] h-[20px] bg-gradient-to-t from-gray-900/20 to-transparent blur-xl rounded-full" />
            </motion.div>
          </div>

          {/* Bottom step counter */}
          <div className="absolute bottom-8 left-0 right-0 text-center">
            <span className="text-5xl font-light text-gray-200">
              {String(activeStep + 1).padStart(2, '0')}
            </span>
            <span className="text-5xl font-light text-gray-300">
              /{String(parentSteps.length).padStart(2, '0')}
            </span>
          </div>
        </div>
      </div>

      {/* Spacer for scroll length */}
      <div className="h-[400vh]" />
    </section>
  );
}
