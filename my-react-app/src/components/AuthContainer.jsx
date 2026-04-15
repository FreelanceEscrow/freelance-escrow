import { createElement, useState } from "react";
import { FaGoogle, FaLinkedinIn, FaGithub } from "react-icons/fa";

const SocialButtons = () => (
  <div className="flex gap-4 justify-center">
    {[
      { Icon: FaGoogle, label: "Google" },
      { Icon: FaLinkedinIn, label: "LinkedIn" },
      { Icon: FaGithub, label: "GitHub" },
    ].map((item) => (
      <button
        key={item.label}
        aria-label={`Sign in with ${item.label}`}
        className="w-11 h-11 rounded-full border border-border/60 flex items-center justify-center text-muted-foreground hover:text-primary hover:border-primary/50 hover:glow-primary transition-all duration-300"
      >
        {createElement(item.Icon, { className: "w-4 h-4" })}
      </button>
    ))}
  </div>
);

const FloatingInput = ({
  id,
  label,
  type = "text",
}) => (
  <div className="relative">
    <input
      id={id}
      type={type}
      placeholder=" "
      className="peer w-full px-4 pt-5 pb-2 bg-secondary/50 border border-border/50 rounded-lg text-foreground placeholder-transparent focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all duration-300"
    />
    <label
      htmlFor={id}
      className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground text-sm transition-all duration-200 pointer-events-none peer-focus:top-3 peer-focus:text-xs peer-focus:text-primary peer-[&:not(:placeholder-shown)]:top-3 peer-[&:not(:placeholder-shown)]:text-xs"
    >
      {label}
    </label>
  </div>
);

const SignInForm = () => (
  <div className="flex flex-col items-center gap-6 w-full max-w-sm mx-auto">
    <h2 className="text-2xl font-bold text-foreground">Sign In</h2>
    <SocialButtons />
    <div className="flex items-center gap-3 w-full">
      <div className="h-px flex-1 bg-border/50" />
      <span className="text-xs text-muted-foreground uppercase tracking-wider">or use email</span>
      <div className="h-px flex-1 bg-border/50" />
    </div>
    <div className="w-full space-y-4">
      <FloatingInput id="signin-email" label="Email" type="email" />
      <FloatingInput id="signin-password" label="Password" type="password" />
    </div>
    <button className="text-xs text-muted-foreground hover:text-primary transition-colors">
      Forgot your password?
    </button>
    <button className="w-full py-3 rounded-lg bg-primary text-primary-foreground font-semibold hover:brightness-110 transition-all duration-300 glow-primary">
      Sign In
    </button>
  </div>
);

const SignUpForm = () => (
  <div className="flex flex-col items-center gap-6 w-full max-w-sm mx-auto">
    <h2 className="text-2xl font-bold text-foreground">Create Account</h2>
    <SocialButtons />
    <div className="flex items-center gap-3 w-full">
      <div className="h-px flex-1 bg-border/50" />
      <span className="text-xs text-muted-foreground uppercase tracking-wider">or use email</span>
      <div className="h-px flex-1 bg-border/50" />
    </div>
    <div className="w-full space-y-4">
      <FloatingInput id="signup-name" label="Full Name" />
      <FloatingInput id="signup-email" label="Email" type="email" />
      <FloatingInput id="signup-password" label="Password" type="password" />
    </div>
    <button className="w-full py-3 rounded-lg bg-primary text-primary-foreground font-semibold hover:brightness-110 transition-all duration-300 glow-primary">
      Sign Up
    </button>
  </div>
);

const AuthContainer = () => {
  const [isSignUp, setIsSignUp] = useState(false);

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      {/* Background glow effects */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 -left-32 w-96 h-96 bg-primary/5 rounded-full blur-3xl" />
        <div className="absolute bottom-1/4 -right-32 w-96 h-96 bg-accent/5 rounded-full blur-3xl" />
      </div>

      {/* Desktop layout */}
      <div className="hidden md:block relative w-full max-w-4xl h-[560px] glass rounded-2xl overflow-hidden glow-primary">
        {/* Form panels */}
        <div className="absolute inset-0 flex">
          {/* Sign In - left half */}
          <div
            className="w-1/2 flex items-center justify-center p-10 transition-all duration-700 ease-in-out"
            style={{
              opacity: isSignUp ? 0 : 1,
              transform: isSignUp ? "translateX(-20%)" : "translateX(0)",
              pointerEvents: isSignUp ? "none" : "auto",
            }}
          >
            <SignInForm />
          </div>
          {/* Sign Up - right half */}
          <div
            className="w-1/2 flex items-center justify-center p-10 transition-all duration-700 ease-in-out"
            style={{
              opacity: isSignUp ? 1 : 0,
              transform: isSignUp ? "translateX(0)" : "translateX(20%)",
              pointerEvents: isSignUp ? "auto" : "none",
            }}
          >
            <SignUpForm />
          </div>
        </div>

        {/* Sliding overlay panel */}
        <div
          className="absolute top-0 w-1/2 h-full transition-transform duration-700 ease-in-out z-10"
          style={{
            transform: isSignUp ? "translateX(0)" : "translateX(100%)",
          }}
        >
          <div className="h-full bg-gradient-to-br from-primary/90 to-accent/80 backdrop-blur-sm flex flex-col items-center justify-center text-center p-10 gap-6">
            <h3 className="text-3xl font-bold text-primary-foreground">
              {isSignUp ? "Welcome Back!" : "Hello, Friend!"}
            </h3>
            <p className="text-primary-foreground/80 text-sm leading-relaxed max-w-xs">
              {isSignUp
                ? "Already have an account? Sign in to access your projects and continue building amazing things."
                : "Ready to start your journey? Create an account and join our community of top freelancers."}
            </p>
            <button
              onClick={() => setIsSignUp(!isSignUp)}
              className="px-8 py-2.5 rounded-full border-2 border-primary-foreground/80 text-primary-foreground font-semibold text-sm hover:bg-primary-foreground/10 transition-all duration-300"
            >
              {isSignUp ? "Sign In" : "Sign Up"}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile layout */}
      <div className="md:hidden w-full max-w-sm">
        <div className="glass rounded-2xl p-8 glow-primary">
          {/* Toggle tabs */}
          <div className="flex mb-8 bg-secondary/50 rounded-lg p-1">
            <button
              onClick={() => setIsSignUp(false)}
              className={`flex-1 py-2.5 rounded-md text-sm font-semibold transition-all duration-300 ${
                !isSignUp
                  ? "bg-primary text-primary-foreground shadow-lg"
                  : "text-muted-foreground"
              }`}
            >
              Sign In
            </button>
            <button
              onClick={() => setIsSignUp(true)}
              className={`flex-1 py-2.5 rounded-md text-sm font-semibold transition-all duration-300 ${
                isSignUp
                  ? "bg-primary text-primary-foreground shadow-lg"
                  : "text-muted-foreground"
              }`}
            >
              Sign Up
            </button>
          </div>

          {/* Animated form container */}
          <div className="relative overflow-hidden">
            <div
              className="transition-all duration-500 ease-in-out"
              style={{
                transform: isSignUp ? "translateX(-100%)" : "translateX(0)",
                opacity: isSignUp ? 0 : 1,
                height: isSignUp ? 0 : "auto",
                overflow: isSignUp ? "hidden" : "visible",
              }}
            >
              <SignInForm />
            </div>
            <div
              className="transition-all duration-500 ease-in-out"
              style={{
                transform: isSignUp ? "translateX(0)" : "translateX(100%)",
                opacity: isSignUp ? 1 : 0,
                height: isSignUp ? "auto" : 0,
                overflow: isSignUp ? "visible" : "hidden",
              }}
            >
              <SignUpForm />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AuthContainer;