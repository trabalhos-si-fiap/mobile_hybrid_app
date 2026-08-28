import { ChangeDetectorRef, Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  FormBuilder,
  ReactiveFormsModule,
  Validators
} from '@angular/forms';
import { Router } from '@angular/router';

import { AuthService } from '../../core/services/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

  passwordVisible = false;
  loading = false;
  errorMessage = '';

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required],
    remember: [false]
  });

  submit(): void {
    if (this.form.invalid || this.loading) {
      this.form.markAllAsTouched();
      return;
    }

    this.loading = true;
    this.errorMessage = '';

    const { email, password, remember } = this.form.getRawValue();

    this.auth.login(email, password, remember).subscribe({
      next: () => {
        this.loading = false;
        this.cdr.markForCheck();
        this.router.navigateByUrl('/dashboard');
      },
      error: error => {
        this.loading = false;
        this.cdr.markForCheck();

        if (error?.status === 401) {
          this.errorMessage = 'E-mail ou senha inválidos.';
          return;
        }

        this.errorMessage =
          'Não consegui falar com a API. Confirme se o Spring está rodando na porta 8080.';
      }
    });
  }
}
