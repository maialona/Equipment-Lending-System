<script setup>
</script>

<template>
  <div class="iso-scene w-full h-full flex items-center justify-center perspective-[1000px]">
    <div class="iso-container relative w-64 h-64 md:w-80 md:h-80 transform-style-3d rotate-x-[60deg] rotate-z-[-45deg] hover:rotate-z-[-40deg] transition-transform duration-700 ease-out">
      
      <!-- Layer 1: Base Plate (Dark Glass) -->
      <div class="absolute inset-0 bg-zinc-900/40 backdrop-blur-md rounded-2xl border border-white/10 shadow-2xl transform-style-3d translate-z-0 animate-float-slow">
         <!-- Abstract Grid Content -->
         <div class="absolute inset-4 grid grid-cols-2 gap-4 opacity-30">
             <div class="bg-gradient-to-br from-zinc-700 to-transparent rounded-lg h-full"></div>
             <div class="bg-gradient-to-br from-zinc-700 to-transparent rounded-lg h-full"></div>
             <div class="bg-gradient-to-br from-zinc-700 to-transparent rounded-lg h-full col-span-2"></div>
         </div>
      </div>

      <!-- Layer 2: Main Card (Lighter Glass) -->
      <div class="absolute top-[-20%] left-[10%] w-[90%] h-[70%] bg-zinc-800/30 backdrop-blur-xl rounded-xl border border-white/20 shadow-xl transform-style-3d translate-z-[40px] animate-float-medium flex flex-col p-4">
          <!-- Header skeleton -->
          <div class="flex items-center gap-3 mb-4">
              <div class="w-8 h-8 rounded-full bg-indigo-500/20 shadow-inner border border-indigo-500/30"></div>
              <div class="h-2 w-20 bg-white/20 rounded-full"></div>
          </div>
          <!-- Chart skeleton -->
          <div class="flex items-end gap-2 h-full pb-2">
             <div class="w-[15%] h-[40%] bg-white/10 rounded-t-sm"></div>
             <div class="w-[15%] h-[70%] bg-indigo-500/40 rounded-t-sm"></div>
             <div class="w-[15%] h-[50%] bg-white/10 rounded-t-sm"></div>
             <div class="w-[15%] h-[85%] bg-indigo-500/60 rounded-t-sm"></div>
             <div class="w-[15%] h-[60%] bg-white/10 rounded-t-sm"></div>
          </div>
      </div>

      <!-- Layer 3: Floating Notification (Accent) -->
      <div class="absolute -right-[10%] bottom-[20%] w-[140px] h-[70px] bg-zinc-900/60 backdrop-blur-2xl rounded-lg border border-emerald-500/30 shadow-lg shadow-emerald-900/20 transform-style-3d translate-z-[80px] animate-float-fast p-3 flex items-center gap-3">
          <div class="w-8 h-8 rounded-full bg-emerald-500/20 flex items-center justify-center">
             <div class="w-2.5 h-1.5 border-l-2 border-b-2 border-emerald-400 rotate-[-45deg] mb-0.5"></div>
          </div>
          <div class="space-y-1.5 w-full">
              <div class="h-1.5 w-2/3 bg-white/40 rounded-full"></div>
              <div class="h-1.5 w-full bg-white/10 rounded-full"></div>
          </div>
      </div>

      <!-- Floating Particles -->
      <div class="absolute -top-10 -right-10 w-12 h-12 rounded-full bg-gradient-to-br from-indigo-500/30 to-purple-500/10 blur-md animate-pulse"></div>

    </div>
  </div>
</template>

<style scoped>
.transform-style-3d {
  transform-style: preserve-3d;
}

.translate-z-0 { transform: translateZ(0px); }
.translate-z-\[40px\] { transform: translateZ(40px); }
.translate-z-\[80px\] { transform: translateZ(80px); }

/* Isometric Rotation Base */
.rotate-x-\[60deg\] { transform: rotateX(60deg) rotateZ(-45deg); }

/* Animation Keyframes */
@keyframes float {
  0%, 100% { transform: translateZ(0px); }
  50% { transform: translateZ(10px); }
}

@keyframes float-medium {
  0%, 100% { transform: translateZ(40px); }
  50% { transform: translateZ(55px); }
}

@keyframes float-fast {
  0%, 100% { transform: translateZ(80px); }
  50% { transform: translateZ(95px); }
}

.animate-float-slow { animation: float 6s ease-in-out infinite; }
.animate-float-medium { animation: float-medium 5s ease-in-out infinite 0.5s; }
.animate-float-fast { animation: float-fast 4s ease-in-out infinite 1s; }
</style>
