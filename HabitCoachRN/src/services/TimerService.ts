import { SessionEndCondition } from '../models/types';

export interface TimerState {
  isRunning: boolean;
  elapsedSeconds: number;
  reminderCount: number;
  secondsUntilNextBuzz: number;
  isComplete: boolean;
}

export interface TimerConfig {
  intervalSeconds: number;
  varianceSeconds: number;
  endCondition: SessionEndCondition;
  onInterval: () => void;
  onComplete?: () => void;
}

export class TimerService {
  private timer: ReturnType<typeof setInterval> | null = null;
  private nextBuzzAt = 0;
  private config: TimerConfig | null = null;
  private sessionStartDate: Date | null = null;
  private _state: TimerState = {
    isRunning: false,
    elapsedSeconds: 0,
    reminderCount: 0,
    secondsUntilNextBuzz: 0,
    isComplete: false,
  };
  private onStateChange: (state: TimerState) => void;

  constructor(onStateChange: (state: TimerState) => void) {
    this.onStateChange = onStateChange;
  }

  get state(): TimerState {
    return { ...this._state };
  }

  get totalCycles(): number | null {
    if (!this.config) return null;
    const { endCondition, intervalSeconds } = this.config;
    switch (endCondition.type) {
      case 'unlimited':
        return null;
      case 'afterCount':
        return endCondition.count;
      case 'afterDuration':
        return intervalSeconds > 0 ? Math.floor(endCondition.seconds / intervalSeconds) : null;
    }
  }

  start(config: TimerConfig) {
    if (config.intervalSeconds <= 0) return;
    this.config = config;
    this._state = {
      isRunning: true,
      elapsedSeconds: 0,
      reminderCount: 0,
      secondsUntilNextBuzz: 0,
      isComplete: false,
    };
    this.sessionStartDate = new Date();
    this.scheduleNextBuzz();
    this.startTicking();
    this.emit();
  }

  reconfigure(config: TimerConfig) {
    this.config = config;
    this._state.elapsedSeconds = 0;
    this._state.reminderCount = 0;
    this._state.isComplete = false;
    this.sessionStartDate = new Date();
    this.scheduleNextBuzz();
    this.emit();
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this._state.isRunning = false;
    this.sessionStartDate = null;
    this.emit();
  }

  resumeFromBackground() {
    if (!this._state.isRunning || !this.sessionStartDate || !this.config) return;

    const now = new Date();
    const wallElapsed = Math.floor((now.getTime() - this.sessionStartDate.getTime()) / 1000);
    const missedSeconds = wallElapsed - this._state.elapsedSeconds;

    if (missedSeconds > 1) {
      this._state.elapsedSeconds = wallElapsed;

      while (this._state.elapsedSeconds >= this.nextBuzzAt && !this.checkComplete()) {
        this._state.reminderCount++;
        this.config.onInterval();
        if (this.checkComplete()) {
          this.config.onComplete?.();
          this.stop();
          return;
        }
        this.scheduleNextBuzz();
      }

      this._state.secondsUntilNextBuzz = Math.max(0, this.nextBuzzAt - this._state.elapsedSeconds);
    }

    if (!this.timer) {
      this.startTicking();
    }
    this.emit();
  }

  private startTicking() {
    if (this.timer) clearInterval(this.timer);
    this.timer = setInterval(() => {
      if (!this._state.isRunning || !this.config) return;

      this._state.elapsedSeconds++;
      this._state.secondsUntilNextBuzz = Math.max(0, this.nextBuzzAt - this._state.elapsedSeconds);

      if (this._state.elapsedSeconds >= this.nextBuzzAt) {
        this._state.reminderCount++;
        this.config.onInterval();

        if (this.checkComplete()) {
          this._state.isComplete = true;
          this.config.onComplete?.();
          this.stop();
        } else {
          this.scheduleNextBuzz();
        }
      }

      this.emit();
    }, 1000);
  }

  private scheduleNextBuzz() {
    if (!this.config) return;
    let next = this.config.intervalSeconds;
    if (this.config.varianceSeconds > 0) {
      const range = this.config.varianceSeconds * 2 + 1;
      next += Math.floor(Math.random() * range) - this.config.varianceSeconds;
      next = Math.max(5, next);
    }
    this.nextBuzzAt = this._state.elapsedSeconds + next;
    this._state.secondsUntilNextBuzz = next;
  }

  private checkComplete(): boolean {
    if (!this.config) return false;
    switch (this.config.endCondition.type) {
      case 'unlimited':
        return false;
      case 'afterCount':
        return this._state.reminderCount >= this.config.endCondition.count;
      case 'afterDuration':
        return this._state.elapsedSeconds >= this.config.endCondition.seconds;
    }
  }

  private emit() {
    this.onStateChange({ ...this._state });
  }
}
