import { CommonModule } from '@angular/common';
import {
  ChangeDetectorRef,
  Component,
  EventEmitter,
  Input,
  OnInit,
  Output,
  inject
} from '@angular/core';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';

import {
  Carrier,
  CarrierStatus
} from '../../core/models/carrier.model';
import { CarrierService } from '../../core/services/carrier.service';

export type CarrierSaveMode = 'created' | 'updated';

@Component({
  selector: 'app-new-carrier-modal',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './new-carrier-modal.component.html',
  styleUrl: './new-carrier-modal.component.scss'
})
export class NewCarrierModalComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly carrierService = inject(CarrierService);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input() carrier: Carrier | null = null;

  @Output() closed = new EventEmitter<void>();
  @Output() saved = new EventEmitter<CarrierSaveMode>();

  saving = false;
  errorMessage = '';

  readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.minLength(2)]],
    location: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
    averageDeliveryDays: [3, [Validators.required, Validators.min(1)]],
    slaPercentage: [
      95,
      [Validators.required, Validators.min(0), Validators.max(100)]
    ],
    status: ['ACTIVE' as CarrierStatus, Validators.required]
  });

  get isEdit(): boolean {
    return this.carrier !== null;
  }

  ngOnInit(): void {
    if (!this.carrier) {
      return;
    }

    this.form.patchValue({
      name: this.carrier.name,
      location: this.carrier.location,
      email: this.carrier.email,
      averageDeliveryDays: this.carrier.averageDeliveryDays,
      slaPercentage: this.carrier.slaPercentage,
      status: this.carrier.status
    });
  }

  setStatus(status: CarrierStatus): void {
    this.form.controls.status.setValue(status);
  }

  close(): void {
    if (!this.saving) {
      this.closed.emit();
    }
  }

  submit(): void {
    if (this.form.invalid || this.saving) {
      this.form.markAllAsTouched();
      return;
    }

    this.saving = true;
    this.errorMessage = '';

    const value = this.form.getRawValue();

    const request = {
      name: value.name.trim(),
      location: value.location.trim(),
      email: value.email.trim(),
      averageDeliveryDays: Number(value.averageDeliveryDays),
      slaPercentage: Number(value.slaPercentage),
      rating: this.carrier?.rating ?? 0,
      status: value.status
    };

    const operation$ = this.carrier
      ? this.carrierService.updateCarrier(this.carrier.id, request)
      : this.carrierService.createCarrier(request);

    operation$.subscribe({
      next: () => {
        this.saving = false;
        this.cdr.markForCheck();
        this.saved.emit(this.carrier ? 'updated' : 'created');
      },
      error: () => {
        this.saving = false;
        this.errorMessage = this.carrier
          ? 'Não foi possível editar a transportadora.'
          : 'Não foi possível adicionar a transportadora.';
        this.cdr.markForCheck();
      }
    });
  }

  onBackdrop(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.close();
    }
  }
}
